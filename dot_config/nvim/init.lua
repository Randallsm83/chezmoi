-- ███╗   ██╗██╗   ██╗██╗███╗   ███╗
-- ████╗  ██║██║   ██║██║████╗ ████║
-- ██╔██╗ ██║██║   ██║██║██╔████╔██║
-- ██║╚██╗██║╚██╗ ██╔╝██║██║╚██╔╝██║
-- ██║ ╚████║ ╚████╔╝ ██║██║ ╚═╝ ██║
-- ╚═╝  ╚═══╝  ╚═══╝  ╚═╝╚═╝     ╚═╝
-- Hyperextensible Vim-based text editor.
-- run `:checkhealth` for more info.

-- Prepend mise shims to PATH
vim.env.PATH = vim.env.HOME .. '/.local/share/mise/shims:' .. vim.env.PATH

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
