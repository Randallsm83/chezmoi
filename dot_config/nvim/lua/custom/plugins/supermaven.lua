-- [[ Supermaven ]]
--
-- Fast inline tab-completion (Copilot alternative). Free tier is usable;
-- run `:SupermavenUseFree` once to authenticate without a subscription, or
-- `:SupermavenUsePro` if you have one.
--
-- Inline ghost text + <Tab> to accept. Coexists with nvim-cmp (which keeps its
-- own popup); the supermaven cmp source is also registered automatically if
-- you ever want to flip `disable_inline_completion = true` and route through
-- nvim-cmp instead.

return {
  {
    'supermaven-inc/supermaven-nvim',
    event = 'InsertEnter',
    cmd = {
      'SupermavenStart',
      'SupermavenStop',
      'SupermavenRestart',
      'SupermavenToggle',
      'SupermavenStatus',
      'SupermavenUseFree',
      'SupermavenUsePro',
      'SupermavenLogout',
      'SupermavenShowLog',
    },
    opts = {
      keymaps = {
        accept_suggestion = '<Tab>',
        clear_suggestion = '<C-]>',
        -- <C-l> is already used by nvim-cmp/luasnip for snippet jumps.
        accept_word = '<C-Right>',
      },
      ignore_filetypes = {
        gitcommit = true,
        gitrebase = true,
        TelescopePrompt = true,
        ['neo-tree'] = true,
        ['neo-tree-popup'] = true,
        Avante = true,
        AvanteInput = true,
        AvanteSelectedFiles = true,
        AvantePromptInput = true,
        ministarter = true,
        snacks_input = true,
        snacks_notif = true,
        bigfile = true,
        help = true,
        qf = true,
      },
      color = {
        suggestion_color = '#808080',
        cterm = 244,
      },
      log_level = 'warn',
      -- Keep inline ghost text. Set to true and rely on nvim-cmp source if
      -- the ghost text fights with cmp's popup.
      disable_inline_completion = false,
      disable_keymaps = false,
    },
  },
}

-- vim: ts=2 sts=2 sw=2 et
