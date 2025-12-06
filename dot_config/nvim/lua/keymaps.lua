-- [[ Basic Keymaps ]]
--  See `:help vim.keymap.set()`

-- Remap easier command prompt
vim.keymap.set("n", ";", ":")

-- Clear highlights on search when pressing <Esc> in normal mode
--  See `:help hlsearch`
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")

-- Diagnostic keymaps
vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Open diagnostic [Q]uickfix list" })

-- Exit terminal mode in the builtin terminal with a shortcut that is a bit easier
-- for people to discover. Otherwise, you normally need to press <C-\><C-n>, which
-- is not what someone will guess without a bit more experience.
--
-- NOTE: This won't work in all terminal emulators/tmux/etc. Try your own mapping
-- or just use <C-\><C-n> to exit terminal mode
vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- Smart Splits (lazy-loaded, wrap in pcall)
local ok, smart_splits = pcall(require, 'smart-splits')
if ok then
  vim.keymap.set("n", "<A-h>", smart_splits.resize_left)
  vim.keymap.set("n", "<A-j>", smart_splits.resize_down)
  vim.keymap.set("n", "<A-k>", smart_splits.resize_up)
  vim.keymap.set("n", "<A-l>", smart_splits.resize_right)
  vim.keymap.set("n", "<C-h>", smart_splits.move_cursor_left)
  vim.keymap.set("n", "<C-j>", smart_splits.move_cursor_down)
  vim.keymap.set("n", "<C-k>", smart_splits.move_cursor_up)
  vim.keymap.set("n", "<C-l>", smart_splits.move_cursor_right)
end

-- vim: ts=2 sts=2 sw=2 et
