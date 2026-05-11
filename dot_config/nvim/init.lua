-- ███╗   ██╗██╗   ██╗██╗███╗   ███╗
-- ████╗  ██║██║   ██║██║████╗ ████║
-- ██╔██╗ ██║██║   ██║██║██╔████╔██║
-- ██║╚██╗██║╚██╗ ██╔╝██║██║╚██╔╝██║
-- ██║ ╚████║ ╚████╔╝ ██║██║ ╚═╝ ██║
-- ╚═╝  ╚═══╝  ╚═══╝  ╚═╝╚═╝     ╚═╝
-- Hyperextensible Vim-based text editor.
--

-- Prepend mise shims to PATH
if vim.fn.has('win32') == 1 then
  vim.env.PATH = vim.env.LOCALAPPDATA .. '\\mise\\shims;' .. vim.env.PATH
else
  vim.env.PATH = vim.env.HOME .. '/.local/share/mise/shims:' .. vim.env.PATH
end

-- Set <leader> and <localleader> BEFORE lazy.nvim is required so plugin
-- specs that use `<leader>...` keys register against the right key.
-- See `:help mapleader`.
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Set to true if you have a Nerd Font installed and selected in the terminal
vim.g.have_nerd_font = true

-- [[ Options ]]
require 'options'

-- [[ Plugins ]]
require 'plugins'

-- [[ Keymaps ]]
require 'keymaps'

-- [[ Colorscheme ]]
require 'colors'

-- [[ Autocommands ]]
require 'autocommands'

----------------------------------------------------------------------------
-- vim: ts=2 sts=2 sw=2 et
