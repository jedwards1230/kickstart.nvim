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
    -- Auto-open on startup, always full-height on the left
    vim.api.nvim_create_autocmd('VimEnter', {
      callback = function()
        vim.schedule(function()
          require('neo-tree.command').execute { action = 'show', position = 'left', source = 'filesystem' }
          vim.cmd 'wincmd p' -- return focus to the file window
        end)
      end,
    })
    vim.api.nvim_create_autocmd('ColorScheme', {
      callback = function()
        vim.api.nvim_set_hl(0, 'NeoTreeGitIgnored', { fg = '#6b6b6b', italic = true })
      end,
    })
    vim.api.nvim_set_hl(0, 'NeoTreeGitIgnored', { fg = '#6b6b6b', italic = true })
  end,
  ---@module 'neo-tree'
  ---@type neotree.Config
  opts = {
    window = {
      position = 'left',
      width = 30,
    },
    filesystem = {
      filtered_items = {
        visible = true,
        hide_dotfiles = false,
        hide_gitignored = false,
      },
      window = {
        mappings = {
          ['\\'] = 'close_window',
        },
      },
    },
  },
}
