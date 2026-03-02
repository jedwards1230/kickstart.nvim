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
      bind_to_cwd = false,
      window = {
        mappings = {
          ['\\'] = 'close_window',
        },
      },
    },
    git_status = {
      window = {
        position = 'left',
      },
    },
  },
}
