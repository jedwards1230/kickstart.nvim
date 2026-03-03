-- Neo-tree is a Neovim plugin to browse the file system
-- https://github.com/nvim-neo-tree/neo-tree.nvim

---@module 'lazy'
---@type LazySpec
return {
  'nvim-neo-tree/neo-tree.nvim',
  version = '*',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-tree/nvim-web-devicons', -- not strictly required, but recommended
    'MunifTanjim/nui.nvim',
  },
  lazy = false,
  keys = {
    { '\\', ':Neotree reveal<CR>', desc = 'NeoTree reveal', silent = true },
  },
  init = function()
    -- Git root of the most recently focused file buffer.
    -- Shared by the BufEnter tracker and the git_status navigate patch.
    local current_git_root = nil

    -- Auto-open on startup, always full-height on the left
    vim.api.nvim_create_autocmd('VimEnter', {
      callback = function()
        vim.schedule(function()
          require('neo-tree.command').execute { action = 'show', position = 'left', source = 'filesystem' }
          vim.cmd 'wincmd p' -- return focus to the file window

          -- Patch git_status.navigate so the Git tab follows the current file's repo.
          -- This intercepts every navigate call (first open, refresh, source switch)
          -- and replaces the path with our tracked git root before items.lua runs
          -- git.status() and overwrites state.path with the parent repo.
          local ok, git_status_source = pcall(require, 'neo-tree.sources.git_status')
          if ok then
            local original_navigate = git_status_source.navigate
            git_status_source.navigate = function(state, path, path_to_reveal, callback, async)
              if current_git_root then
                path = current_git_root
              end
              return original_navigate(state, path, path_to_reveal, callback, async)
            end
          end

          -- Register nested git repos for correct per-repo status markers
          vim.defer_fn(function()
            pcall(function()
              require('custom.nested_git').setup()
            end)
          end, 500)
        end)
      end,
    })

    vim.api.nvim_create_autocmd('ColorScheme', {
      callback = function()
        vim.api.nvim_set_hl(0, 'NeoTreeGitIgnored', { fg = '#6b6b6b', italic = true })
      end,
    })
    vim.api.nvim_set_hl(0, 'NeoTreeGitIgnored', { fg = '#6b6b6b', italic = true })

    -- Helper: push current_git_root into the git_status state so the
    -- Git tab shows the right repo on next open/refresh.
    local function update_git_status_state()
      pcall(function()
        local manager = require 'neo-tree.sources.manager'
        local state = manager.get_state 'git_status'
        if not state then return end
        state.path = current_git_root
        -- If Git tab is visible, refresh immediately
        if state.bufnr and vim.api.nvim_buf_is_valid(state.bufnr) then
          local wins = vim.fn.win_findbuf(state.bufnr)
          if #wins > 0 then
            manager.refresh 'git_status'
            return
          end
        end
        -- Not visible — mark dirty so next tab switch triggers navigate
        state.dirty = true
      end)
    end

    -- Track which git repo the current file belongs to.
    -- Updates git_status state.path + dirty flag so the Git tab always
    -- reflects the correct repo, whether it's currently visible or not.
    vim.api.nvim_create_autocmd('BufEnter', {
      callback = function()
        if vim.bo.filetype == 'neo-tree' or vim.bo.buftype ~= '' then return end
        local buf_path = vim.api.nvim_buf_get_name(0)
        if buf_path == '' then return end

        local ok, nested_git = pcall(require, 'custom.nested_git')
        if not ok then return end
        local new_root = nested_git.find_git_root(buf_path)
        if not new_root or new_root == current_git_root then return end
        current_git_root = new_root
        update_git_status_state()
      end,
    })

    -- When :cd changes the working directory, update the Git tab root.
    -- Filesystem re-roots automatically via bind_to_cwd = true.
    vim.api.nvim_create_autocmd('DirChanged', {
      callback = function()
        local new_cwd = vim.fn.getcwd()
        local ok, nested_git = pcall(require, 'custom.nested_git')
        if not ok then return end
        local new_root = nested_git.find_git_root(new_cwd)
        if not new_root then
          -- cwd itself might be a git root (e.g. :cd into a nested repo)
          local git_dir = vim.fn.finddir('.git', new_cwd)
          if git_dir ~= '' then
            new_root = new_cwd
          end
        end
        if not new_root or new_root == current_git_root then return end
        current_git_root = new_root
        update_git_status_state()
      end,
    })
  end,
  ---@module 'neo-tree'
  ---@type neotree.Config
  opts = {
    -- Tabbed source selector in the winbar (Files | Git | Buffers)
    source_selector = {
      winbar = true,
      sources = {
        { source = 'filesystem', display_name = ' Files' },
        { source = 'git_status', display_name = ' Git' },
        { source = 'buffers', display_name = ' Buffers' },
      },
    },
    window = {
      position = 'left',
      width = 30,
      mappings = {
        -- Arrow keys to switch tabs (in addition to default < and >)
        ['<left>'] = 'prev_source',
        ['<right>'] = 'next_source',
      },
    },
    filesystem = {
      filtered_items = {
        visible = true,
        hide_dotfiles = false,
        hide_gitignored = false,
      },
      follow_current_file = { enabled = true },
      use_libuv_file_watcher = true,
      bind_to_cwd = true,
      window = {
        mappings = {
          ['\\'] = 'close_window',
        },
      },
    },
    git_status = {
      window = {
        position = 'left',
        mappings = {
          ['gd'] = function(state)
            local node = state.tree:get_node()
            if node and node.path then
              -- Open the file in the editor, then diff it inline via gitsigns
              vim.cmd('wincmd p')
              vim.cmd('edit ' .. vim.fn.fnameescape(node.path))
              vim.schedule(function()
                require('gitsigns').diffthis()
              end)
            end
          end,
        },
      },
    },
  },
}
