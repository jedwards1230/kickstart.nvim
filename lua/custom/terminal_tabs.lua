--- Tabbed terminal panel for the bottom of the editor.
--- Manages multiple persistent terminal buffers in one window,
--- with a winbar tab strip. Any tab can run `claude` and get
--- full nvim integration via claudecode.nvim's background server.

local M = {}

M.terminals = {} -- { buf=n, name=string, chan=n }
M.active = 0 -- 1-indexed into terminals, 0 = none
M.win = nil -- the bottom panel window

local HEIGHT_PCT = 0.35

-- ── Helpers ────────────────────────────────────────────────────────────────

local function win_valid()
  return M.win ~= nil and vim.api.nvim_win_is_valid(M.win)
end

-- Find the main editor window (skip neo-tree, terminals, quickfix, etc.)
local function find_editor_win()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    local bt = vim.bo[buf].buftype
    local ft = vim.bo[buf].filetype
    if bt == '' and ft ~= 'neo-tree' then
      return win
    end
  end
  return vim.api.nvim_get_current_win()
end

-- ── Winbar rendering ───────────────────────────────────────────────────────

local function render_winbar()
  if not win_valid() then return end
  -- Expose module globally so v:lua can reach it (required for %@funcname@ click regions)
  _G._TermTab = M
  local parts = {}
  for i, t in ipairs(M.terminals) do
    local label = ' ' .. (t.name or ('terminal ' .. i)) .. ' '
    if i == M.active then
      table.insert(parts, '%#TabLineSel#' .. label .. '%*')
    else
      -- %N@funcname@text%X — N is passed as minwid to funcname(minwid, clicks, button, mods)
      table.insert(parts, string.format(
        '%%%d@v:lua._TermTab.click@%%#TabLine#%s%%*%%X',
        i, label
      ))
    end
    if i < #M.terminals then
      table.insert(parts, '%#TabLineFill# │ %*')
    end
  end
  -- New tab button (minwid 0 = unused)
  table.insert(parts, ' %0@v:lua._TermTab.new_click@%#TabLine# + %*%X')
  vim.wo[M.win].winbar = table.concat(parts)
end

-- ── Window management ──────────────────────────────────────────────────────

local function setup_win()
  if win_valid() then return end
  local orig = vim.api.nvim_get_current_win()
  local editor_win = find_editor_win()
  local height = math.max(10, math.floor(vim.o.lines * HEIGHT_PCT))

  -- Split below the editor window only (not full-width botright)
  vim.api.nvim_set_current_win(editor_win)
  vim.cmd('belowright ' .. height .. 'split')
  M.win = vim.api.nvim_get_current_win()

  local wo = vim.wo[M.win]
  wo.winfixheight = true
  wo.number = false
  wo.relativenumber = false
  wo.signcolumn = 'no'
  wo.foldcolumn = '0'
  wo.statusline = ' '

  -- Return focus to original window
  if vim.api.nvim_win_is_valid(orig) and orig ~= M.win then
    vim.api.nvim_set_current_win(orig)
  end
end

-- ── Terminal lifecycle ─────────────────────────────────────────────────────

local function on_term_exit(buf)
  -- Runs via vim.schedule — safe to call nvim API
  for i, t in ipairs(M.terminals) do
    if t.buf == buf then
      table.remove(M.terminals, i)
      if M.active > i then M.active = M.active - 1 end
      if M.active > #M.terminals then M.active = #M.terminals end
      break
    end
  end

  if #M.terminals == 0 then
    if win_valid() then
      pcall(vim.api.nvim_win_close, M.win, true)
      M.win = nil
    end
  elseif win_valid() then
    local idx = math.max(1, M.active)
    M.active = idx
    vim.api.nvim_win_set_buf(M.win, M.terminals[idx].buf)
    render_winbar()
  end

  pcall(vim.api.nvim_buf_delete, buf, { force = true })
end

-- ── Public API ─────────────────────────────────────────────────────────────

--- Open a new terminal tab with optional name.
--- If send_cmd is provided, it's typed into the shell after launch.
function M.new_tab(name, send_cmd)
  name = name or ('shell ' .. (#M.terminals + 1))
  setup_win()

  local buf, chan
  vim.api.nvim_win_call(M.win, function()
    vim.cmd 'enew'
    buf = vim.api.nvim_get_current_buf()
    chan = vim.fn.termopen(vim.o.shell, {
      on_exit = function()
        vim.schedule(function() on_term_exit(buf) end)
      end,
    })
    vim.bo[buf].buflisted = false
  end)

  table.insert(M.terminals, { buf = buf, name = name, chan = chan })
  M.active = #M.terminals
  vim.api.nvim_win_set_buf(M.win, buf)
  render_winbar()
  vim.api.nvim_set_current_win(M.win)
  vim.cmd 'startinsert'

  if send_cmd then
    vim.defer_fn(function()
      if chan and vim.api.nvim_buf_is_valid(buf) then
        vim.fn.jobsend(chan, send_cmd .. '\n')
      end
    end, 150) -- small delay for shell to be ready
  end
end

--- Switch to terminal tab at index.
function M.switch(idx)
  if not M.terminals[idx] then return end
  if not win_valid() then setup_win() end
  M.active = idx
  vim.api.nvim_win_set_buf(M.win, M.terminals[idx].buf)
  render_winbar()
  vim.api.nvim_set_current_win(M.win)
  vim.cmd 'startinsert'
end

--- Toggle the panel open/closed.
function M.toggle()
  if win_valid() then
    vim.api.nvim_win_close(M.win, false)
    M.win = nil
  elseif #M.terminals == 0 then
    M.new_tab()
  else
    local idx = M.active > 0 and M.active or 1
    M.active = idx
    setup_win()
    vim.api.nvim_win_set_buf(M.win, M.terminals[idx].buf)
    render_winbar()
    vim.api.nvim_set_current_win(M.win)
    vim.cmd 'startinsert'
  end
end

--- Cycle to next terminal tab.
function M.next()
  if #M.terminals == 0 then return end
  M.switch((M.active % #M.terminals) + 1)
end

--- Cycle to previous terminal tab.
function M.prev()
  if #M.terminals == 0 then return end
  M.switch(((M.active - 2) % #M.terminals) + 1)
end

--- Close the active terminal tab.
function M.close_tab()
  local t = M.terminals[M.active]
  if not t then return end
  vim.fn.jobstop(t.chan) -- triggers on_exit → cleanup
end

--- Open a new tab and launch claude in it.
function M.open_claude()
  M.new_tab('claude', 'claude')
end

--- Rename the active tab.
function M.rename(name)
  if M.terminals[M.active] then
    M.terminals[M.active].name = name
    render_winbar()
  end
end

-- ── Click handlers (called via v:lua from winbar) ──────────────────────────
-- Signature: (minwid, clicks, button, mods) — minwid encodes the tab index

function M.click(idx, clicks, button, mods)
  M.switch(idx)
end

function M.new_click(minwid, clicks, button, mods)
  M.new_tab()
end

return M
