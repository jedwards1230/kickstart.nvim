-- You can add your own plugins here or in other files in this directory!
--  I promise not to create any merge conflicts in this directory :)
--
-- See the kickstart.nvim README for more information
---@module 'lazy'
---@type LazySpec
return {
  {
    'coder/claudecode.nvim',
    lazy = false,
    dependencies = { 'folke/snacks.nvim' },
    opts = {
      auto_start = true,
      track_selection = true,
      focus_after_send = false,
      models = {
        { name = 'Claude Opus 4.6 (Latest)', value = 'opus' },
        { name = 'Claude Sonnet 4.6 (Latest)', value = 'sonnet' },
        { name = 'Claude Haiku 4.5 (Latest)', value = 'haiku' },
      },
      terminal = {
        split_side = 'right',
        split_width_percentage = 0.35,
        provider = 'snacks',
        auto_close = true,
        snacks_win_opts = {
          position = 'bottom',
          height = 0.35,
          width = 0,
          relative = 'win',
        },
      },
      diff_opts = {
        auto_close_on_accept = true,
        vertical_split = true,
        open_in_current_tab = true,
      },
    },
    -- claudecode.nvim runs as a background MCP server.
    -- Use <leader>ac to open a terminal tab and launch claude there.
    -- Any terminal running `claude` connects automatically via lock file.
    keys = {
      { '<leader>as', '<cmd>ClaudeCodeSend<cr>', mode = 'v', desc = '[A]I [S]end selection to Claude' },
      { '<leader>ab', '<cmd>ClaudeCodeAdd %<cr>', desc = '[A]I add current [B]uffer to context' },
      { '<leader>aa', '<cmd>ClaudeCodeDiffAccept<cr>', desc = '[A]I [A]ccept diff' },
      { '<leader>ad', '<cmd>ClaudeCodeDiffDeny<cr>', desc = '[A]I [D]eny diff' },
    },
  },
  -- Ghostty config syntax highlighting + validation (lazy: only loads for ghostty config files)
  { 'isak102/ghostty.nvim', ft = 'ghostty' },

  -- Side-by-side diff viewer and file history
  {
    'sindrets/diffview.nvim',
    cmd = { 'DiffviewOpen', 'DiffviewFileHistory', 'DiffviewClose' },
    keys = {
      { '<leader>gd', '<cmd>DiffviewOpen<cr>', desc = '[G]it [D]iff view' },
      { '<leader>gh', '<cmd>DiffviewFileHistory %<cr>', desc = '[G]it file [H]istory' },
      { '<leader>gH', '<cmd>DiffviewFileHistory<cr>', desc = '[G]it repo [H]istory' },
      { '<leader>gq', '<cmd>DiffviewClose<cr>', desc = '[G]it diff [Q]uit' },
    },
  },

  -- VS Code-style buffer tabs at the top
  {
    'akinsho/bufferline.nvim',
    version = '*',
    dependencies = 'nvim-tree/nvim-web-devicons',
    event = 'VeryLazy',
    opts = {
      options = {
        diagnostics = 'nvim_lsp',         -- show LSP error/warn counts on tabs
        offsets = {
          { filetype = 'neo-tree', text = 'File Explorer', highlight = 'Directory', separator = true },
        },
        separator_style = 'slant',
        show_buffer_close_icons = true,
        show_close_icon = false,
      },
    },
    keys = {
      { '<Tab>', '<cmd>BufferLineCycleNext<cr>', desc = 'Next buffer tab' },
      { '<S-Tab>', '<cmd>BufferLineCyclePrev<cr>', desc = 'Prev buffer tab' },
      { '<leader>x', '<cmd>bprevious<cr><cmd>bdelete #<cr>', desc = 'Close buffer (keep layout)' },
    },
  },

}
