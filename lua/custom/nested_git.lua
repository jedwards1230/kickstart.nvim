-- Nested git repo support for Neo-tree
--
-- Problem: Neo-tree's fs_scan detects .git dirs in subdirectories but skips
-- registration because find_existing_worktree() returns the parent repo
-- (the child .git path IS inside the parent worktree). Additionally,
-- find_existing_worktree uses pairs() which has non-deterministic ordering,
-- so even registered nested repos might not be found correctly.
--
-- Solution:
-- 1. Monkey-patch find_existing_worktree to return the deepest matching worktree
-- 2. Force-register nested repos via git.status_async (bypasses the fs_scan gate)
-- 3. Clear cache and refresh so correct status is displayed

local M = {}

--- Cached list of discovered nested repo paths (sorted longest-first)
M._repos = {}

--- Find directories containing .git under root (skips node_modules, depth limit 4)
---@param root string
---@return string[]
function M.find_nested_repos(root)
  local repos = {}

  local function scan(dir, depth)
    if depth > 4 then return end
    local handle = vim.uv.fs_scandir(dir)
    if not handle then return end
    local has_git = false
    local subdirs = {}
    while true do
      local name, ftype = vim.uv.fs_scandir_next(handle)
      if not name then break end
      if name == '.git' then
        has_git = true
      elseif ftype == 'directory' and name ~= 'node_modules' and name ~= '.git' then
        subdirs[#subdirs + 1] = dir .. '/' .. name
      end
    end
    if has_git and dir ~= root then
      repos[#repos + 1] = dir
      return -- don't recurse into repos (they're independent)
    end
    for _, subdir in ipairs(subdirs) do
      scan(subdir, depth + 1)
    end
  end

  scan(root, 0)
  -- Sort longest-first so find_repo_for_path matches the most specific repo
  table.sort(repos, function(a, b) return #a > #b end)
  return repos
end

--- Patch Neo-tree's worktree lookup to return the deepest (most specific) match.
--- Without this, pairs() iteration may return a parent repo for paths inside a nested repo.
function M.patch_worktree_lookup()
  local ok, git = pcall(require, 'neo-tree.git')
  if not ok then return end
  local utils = require 'neo-tree.utils'

  git.find_existing_worktree = function(path)
    local cached = git._upward_worktree_cache[path]
    if cached ~= nil then
      local worktree = cached and git.worktrees[cached]
      return cached or nil, worktree
    end
    -- Find the deepest (longest path) matching worktree
    local best_root, best_info = nil, nil
    for worktree_root, worktree in pairs(git.worktrees) do
      if utils.is_subpath(worktree_root, path, true) then
        if not best_root or #worktree_root > #best_root then
          best_root = worktree_root
          best_info = worktree
        end
      end
    end
    if best_root then
      git._upward_worktree_cache[path] = best_root
      return best_root, best_info
    end
    git._upward_worktree_cache[path] = false
    return nil, nil
  end
end

--- Find which repo a file path belongs to (uses cached repo list)
---@param path string
---@return string? repo_root
function M.find_repo_for_path(path)
  -- Check nested repos (already sorted longest-first)
  for _, repo in ipairs(M._repos) do
    if vim.startswith(path, repo .. '/') then
      return repo
    end
  end
  return nil
end

--- Discover and register nested repos with Neo-tree
---@param root string? workspace root (defaults to cwd)
function M.setup(root)
  root = root or vim.fn.getcwd()

  -- Patch lookup to prefer deepest match
  M.patch_worktree_lookup()

  -- Find nested repos
  local repos = M.find_nested_repos(root)
  M._repos = repos
  if #repos == 0 then return end

  local git = require 'neo-tree.git'
  local nt_config = require('neo-tree').config
  local async_opts = nt_config and nt_config.git_status_async_options or {}

  -- Force-register each nested repo via async git status
  for _, repo_path in ipairs(repos) do
    pcall(git.status_async, repo_path, nil, async_opts)
  end

  -- After async registration completes, clear cache and refresh
  vim.defer_fn(function()
    git._upward_worktree_cache = setmetatable({}, { __mode = 'kv' })
    pcall(function()
      require('neo-tree.sources.manager').refresh 'filesystem'
    end)
  end, 2000)
end

return M
