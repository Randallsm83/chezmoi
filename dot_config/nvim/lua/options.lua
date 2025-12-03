-- [[ Vim Opts ]]

-- Node provider (skip yarn detection)
vim.g.node_host_prog = vim.fn.exepath('neovim-node-host')

-- Wildmenu
vim.opt.wildmode = "longest:full,full"
vim.opt.wildoptions = "pum,tagfile,fuzzy"
vim.opt.wildignorecase = true

-- Sync clipboard between OS and Neovim.
--  Schedule the setting after `UiEnter` because it can increase startup-time.
--  Remove this option if you want your OS clipboard to remain independent.
--  See `:help 'clipboard'`
vim.schedule(function()
  vim.opt.clipboard = "unnamedplus"
end)

-- Decrease update time
vim.opt.updatetime = 250

-- Decrease mapped sequence wait time
-- Displays which-key popup sooner
vim.opt.timeoutlen = 300

-- Sets how neovim will display certain whitespace characters in the editor.
--  See `:help 'list'`
--  and `:help 'listchars'`
vim.opt.listchars = 'tab:> ,extends:…,precedes:…,nbsp:␣,trail:.'

-- Preview substitutions live, as you type!
vim.opt.inccommand = "split"

-- Minimal number of screen lines to keep above and below the cursor.
vim.opt.scrolloff = 10

-- Smoother scrolling
vim.opt.lazyredraw = true
vim.opt.smoothscroll = true

-- Window title
vim.opt.title = true

-- Hide cmd bar
vim.opt.cmdheight = 0

-- Don't show what me what I'm typing
vim.opt.showcmd = false

-- Show matching brackets
vim.opt.showmatch = true

-- Allow conceal syntax
vim.opt.conceallevel = 1

-- vim: ts=2 sts=2 sw=2 et
