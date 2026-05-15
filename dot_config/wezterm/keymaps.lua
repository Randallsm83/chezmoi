-- ██╗    ██╗███████╗███████╗████████╗███████╗██████╗ ███╗   ███╗
-- ██║    ██║██╔════╝╚══███╔╝╚══██╔══╝██╔════╝██╔══██╗████╗ ████║
-- ██║ █╗ ██║█████╗    ███╔╝    ██║   █████╗  ██████╔╝██╔████╔██║
-- ██║███╗██║██╔══╝   ███╔╝     ██║   ██╔══╝  ██╔══██╗██║╚██╔╝██║
-- ╚███╔███╔╝███████╗███████╗   ██║   ███████╗██║  ██║██║ ╚═╝ ██║
--  ╚══╝╚══╝ ╚══════╝╚══════╝   ╚═╝   ╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝
-- Key mappings — leader-driven, vim-friendly, cross-platform.

local wezterm = require("wezterm")
local act = wezterm.action
local M = {}

-- ─────────────────────────────────────────────────────────────────────────────
-- Keymap reference (mnemonics)
-- ─────────────────────────────────────────────────────────────────────────────
--
-- LEADER ............ CTRL+;
--
-- ─ Application ───────────────────────────────────────────────
-- CTRL+SHIFT+P ...... Command palette
-- CTRL+SHIFT+L ...... Debug overlay
-- F11 / LEADER+F .... Toggle fullscreen
-- CTRL+SHIFT+R ...... Reload config
-- CTRL+SHIFT+Q ...... Quit application
-- CTRL+SHIFT+N ...... New OS window
-- CTRL+SHIFT+= / - .. Font size +/- (also CTRL+SHIFT+0 reset)
-- LEADER+O .......... Cycle window opacity (1.0 → 0.95 → 0.85 → 0.75)
--
-- ─ Tabs ──────────────────────────────────────────────────────
-- CTRL+SHIFT+T ...... New tab
-- CTRL+SHIFT+W ...... Close tab (with confirm)
-- CTRL+1..9 ......... Activate tab 1..9 (9 = last)
-- CTRL+SHIFT+] / [ .. Next / prev tab
-- CTRL+SHIFT+→ / ← .. Move tab right / left
-- LEADER+, .......... Rename current tab
--
-- ─ Panes ─────────────────────────────────────────────────────
-- LEADER+\ / -  ..... Split right / down  (LEADER+| also splits right)
-- LEADER+D .......... Close pane (with confirm)
-- LEADER+Z .......... Zoom toggle
-- CTRL+h/j/k/l ...... Move between panes (smart-splits, vim-aware)
-- META+h/j/k/l ...... Resize panes (smart-splits, vim-aware)
-- LEADER+R .......... Resize-pane mode (hjkl/arrows; ESC/Enter/q exits)
-- LEADER+SPACE ...... Rotate panes clockwise
-- LEADER+! .......... Break pane into its own tab
-- LEADER+@ .......... Swap pane with another (visual picker)
--
-- ─ Workspaces ────────────────────────────────────────────────
-- LEADER+S .......... Show workspace launcher (fuzzy)
-- LEADER+W .......... Rename current workspace
-- LEADER+N / P ...... Next / prev workspace
--
-- ─ Copy / search ─────────────────────────────────────────────
-- CTRL+SHIFT+C / V .. Copy / paste
-- LEADER+[ .......... Enter copy mode (vi-style; tmux-compatible)
-- LEADER+/ .......... Search
-- LEADER+Y .......... Quick-select (open links/SHAs/etc.)
-- LEADER+U .......... Character picker
-- LEADER+K .......... Clear scrollback + viewport
--
-- ─ Domains (WSL / SSH) ───────────────────────────────────────
-- LEADER+G .......... Spawn into a WSL distro / SSH domain

function M.apply_to_config(config)
  config.disable_default_key_bindings = true
  config.enable_kitty_keyboard = true
  config.leader = { key = ";", mods = "CTRL", timeout_milliseconds = 1500 }

  -- ───────────────────────────────────────────────────────────────────────────
  -- smart-splits.nvim integration — seamless h/j/k/l between wezterm panes and
  -- nvim splits. Plugin sets IS_NVIM user var while nvim is active.
  -- ───────────────────────────────────────────────────────────────────────────
  -- Plugin is required for its side-effects; we just need the IS_NVIM detection.
  pcall(wezterm.plugin.require, "https://github.com/mrjones2014/smart-splits.nvim")

  local function is_vim(pane)
    return pane:get_user_vars().IS_NVIM == "true"
  end

  local dir = { h = "Left", j = "Down", k = "Up", l = "Right" }

  local function split_nav(kind, key)
    local mods = kind == "resize" and "META" or "CTRL"
    return {
      key = key,
      mods = mods,
      action = wezterm.action_callback(function(win, pane)
        if is_vim(pane) then
          win:perform_action({ SendKey = { key = key, mods = mods } }, pane)
        elseif kind == "resize" then
          win:perform_action({ AdjustPaneSize = { dir[key], 3 } }, pane)
        else
          win:perform_action({ ActivatePaneDirection = dir[key] }, pane)
        end
      end),
    }
  end

  -- ───────────────────────────────────────────────────────────────────────────
  -- Opacity cycler (LEADER+O)
  -- ───────────────────────────────────────────────────────────────────────────
  local opacity_levels = { 1.0, 0.95, 0.85, 0.75 }
  local opacity_idx = 1
  local toggle_opacity = wezterm.action_callback(function(win)
    opacity_idx = (opacity_idx % #opacity_levels) + 1
    local overrides = win:get_config_overrides() or {}
    overrides.window_background_opacity = opacity_levels[opacity_idx]
    win:set_config_overrides(overrides)
  end)

  -- ───────────────────────────────────────────────────────────────────────────
  -- Inline prompts
  -- ───────────────────────────────────────────────────────────────────────────
  local rename_tab = act.PromptInputLine({
    description = "Tab name:",
    action = wezterm.action_callback(function(win, _, line)
      if line then win:active_tab():set_title(line) end
    end),
  })

  local rename_workspace = act.PromptInputLine({
    description = "Workspace name:",
    action = wezterm.action_callback(function(_, _, line)
      if line and #line > 0 then
        wezterm.mux.rename_workspace(wezterm.mux.get_active_workspace(), line)
      end
    end),
  })

  -- ───────────────────────────────────────────────────────────────────────────
  -- Main key bindings
  -- ───────────────────────────────────────────────────────────────────────────
  config.keys = {
    -- ── Application ──────────────────────────────────────────
    { key = "p",          mods = "CTRL|SHIFT",  action = act.ActivateCommandPalette },
    { key = "l",          mods = "CTRL|SHIFT",  action = act.ShowDebugOverlay },
    { key = "F11",        mods = "NONE",        action = act.ToggleFullScreen },
    { key = "f",          mods = "LEADER",      action = act.ToggleFullScreen },
    { key = "r",          mods = "CTRL|SHIFT",  action = act.ReloadConfiguration },
    { key = "q",          mods = "CTRL|SHIFT",  action = act.QuitApplication },
    { key = "n",          mods = "CTRL|SHIFT",  action = act.SpawnWindow },
    { key = "=",          mods = "CTRL|SHIFT",  action = act.IncreaseFontSize },
    { key = "-",          mods = "CTRL|SHIFT",  action = act.DecreaseFontSize },
    { key = "0",          mods = "CTRL|SHIFT",  action = act.ResetFontSize },
    { key = "o",          mods = "LEADER",      action = toggle_opacity },

    -- ── Tabs ─────────────────────────────────────────────────
    { key = "t",          mods = "CTRL|SHIFT",  action = act.SpawnTab("CurrentPaneDomain") },
    { key = "w",          mods = "CTRL|SHIFT",  action = act.CloseCurrentTab({ confirm = true }) },
    { key = "1",          mods = "CTRL",        action = act.ActivateTab(0) },
    { key = "2",          mods = "CTRL",        action = act.ActivateTab(1) },
    { key = "3",          mods = "CTRL",        action = act.ActivateTab(2) },
    { key = "4",          mods = "CTRL",        action = act.ActivateTab(3) },
    { key = "5",          mods = "CTRL",        action = act.ActivateTab(4) },
    { key = "6",          mods = "CTRL",        action = act.ActivateTab(5) },
    { key = "7",          mods = "CTRL",        action = act.ActivateTab(6) },
    { key = "8",          mods = "CTRL",        action = act.ActivateTab(7) },
    { key = "9",          mods = "CTRL",        action = act.ActivateTab(-1) },
    { key = "[",          mods = "CTRL|SHIFT",  action = act.ActivateTabRelative(-1) },
    { key = "]",          mods = "CTRL|SHIFT",  action = act.ActivateTabRelative(1) },
    { key = "LeftArrow",  mods = "CTRL|SHIFT",  action = act.MoveTabRelative(-1) },
    { key = "RightArrow", mods = "CTRL|SHIFT",  action = act.MoveTabRelative(1) },
    { key = ",",          mods = "LEADER",      action = rename_tab },

    -- ── Panes ────────────────────────────────────────────────
    { key = "\\",         mods = "LEADER",       action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
    { key = "|",          mods = "LEADER|SHIFT", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
    { key = "-",          mods = "LEADER",       action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
    { key = "d",          mods = "LEADER",       action = act.CloseCurrentPane({ confirm = true }) },
    { key = "z",          mods = "LEADER",       action = act.TogglePaneZoomState },
    { key = " ",          mods = "LEADER",       action = act.RotatePanes("Clockwise") },
    { key = "!",          mods = "LEADER|SHIFT", action = act.PaneSelect({ mode = "MoveToNewTab" }) },
    { key = "@",          mods = "LEADER|SHIFT", action = act.PaneSelect({ mode = "SwapWithActive" }) },

    -- Pane navigation / resize (smart-splits aware)
    split_nav("move",   "h"),
    split_nav("move",   "j"),
    split_nav("move",   "k"),
    split_nav("move",   "l"),
    split_nav("resize", "h"),
    split_nav("resize", "j"),
    split_nav("resize", "k"),
    split_nav("resize", "l"),

    -- Modal resize mode
    {
      key = "r", mods = "LEADER",
      action = act.ActivateKeyTable({ name = "resize_pane", one_shot = false, timeout_milliseconds = 4000 }),
    },

    -- ── Workspaces ───────────────────────────────────────────
    { key = "s",          mods = "LEADER",      action = act.ShowLauncherArgs({ flags = "FUZZY|WORKSPACES" }) },
    { key = "w",          mods = "LEADER",      action = rename_workspace },
    { key = "n",          mods = "LEADER",      action = act.SwitchWorkspaceRelative(1) },
    { key = "p",          mods = "LEADER",      action = act.SwitchWorkspaceRelative(-1) },

    -- ── Copy / paste / search ────────────────────────────────
    { key = "c",          mods = "CTRL|SHIFT",  action = act.CopyTo("Clipboard") },
    { key = "v",          mods = "CTRL|SHIFT",  action = act.PasteFrom("Clipboard") },
    { key = "Copy",       mods = "NONE",        action = act.CopyTo("Clipboard") },
    { key = "Paste",      mods = "NONE",        action = act.PasteFrom("Clipboard") },
    { key = "[",          mods = "LEADER",      action = act.ActivateCopyMode },
    { key = "/",          mods = "LEADER",      action = act.Search({ CaseInSensitiveString = "" }) },
    { key = "y",          mods = "LEADER",      action = act.QuickSelect },
    {
      key = "u", mods = "LEADER",
      action = act.CharSelect({ copy_on_select = true, copy_to = "ClipboardAndPrimarySelection" }),
    },
    { key = "k",          mods = "LEADER",      action = act.ClearScrollback("ScrollbackAndViewport") },

    -- ── Domain launcher (WSL / SSH) ──────────────────────────
    { key = "g",          mods = "LEADER",      action = act.ShowLauncherArgs({ flags = "FUZZY|DOMAINS" }) },
  }

  -- ───────────────────────────────────────────────────────────────────────────
  -- Key tables (modal modes)
  -- ───────────────────────────────────────────────────────────────────────────
  config.key_tables = {
    -- LEADER+R → mash hjkl/arrows; ESC/Enter/q exits.
    resize_pane = {
      { key = "h",          mods = "NONE", action = act.AdjustPaneSize({ "Left", 3 }) },
      { key = "j",          mods = "NONE", action = act.AdjustPaneSize({ "Down", 3 }) },
      { key = "k",          mods = "NONE", action = act.AdjustPaneSize({ "Up", 3 }) },
      { key = "l",          mods = "NONE", action = act.AdjustPaneSize({ "Right", 3 }) },
      { key = "LeftArrow",  mods = "NONE", action = act.AdjustPaneSize({ "Left", 1 }) },
      { key = "DownArrow",  mods = "NONE", action = act.AdjustPaneSize({ "Down", 1 }) },
      { key = "UpArrow",    mods = "NONE", action = act.AdjustPaneSize({ "Up", 1 }) },
      { key = "RightArrow", mods = "NONE", action = act.AdjustPaneSize({ "Right", 1 }) },
      { key = "Escape",     mods = "NONE", action = "PopKeyTable" },
      { key = "Enter",      mods = "NONE", action = "PopKeyTable" },
      { key = "q",          mods = "NONE", action = "PopKeyTable" },
    },

    -- Vi-style copy mode
    copy_mode = {
      { key = "Escape",     mods = "NONE",  action = act.CopyMode("Close") },
      { key = "q",          mods = "NONE",  action = act.CopyMode("Close") },
      { key = "h",          mods = "NONE",  action = act.CopyMode("MoveLeft") },
      { key = "j",          mods = "NONE",  action = act.CopyMode("MoveDown") },
      { key = "k",          mods = "NONE",  action = act.CopyMode("MoveUp") },
      { key = "l",          mods = "NONE",  action = act.CopyMode("MoveRight") },
      { key = "w",          mods = "NONE",  action = act.CopyMode("MoveForwardWord") },
      { key = "b",          mods = "NONE",  action = act.CopyMode("MoveBackwardWord") },
      { key = "e",          mods = "NONE",  action = act.CopyMode("MoveForwardWordEnd") },
      { key = "0",          mods = "NONE",  action = act.CopyMode("MoveToStartOfLine") },
      { key = "^",          mods = "SHIFT", action = act.CopyMode("MoveToStartOfLineContent") },
      { key = "$",          mods = "SHIFT", action = act.CopyMode("MoveToEndOfLineContent") },
      { key = "g",          mods = "NONE",  action = act.CopyMode("MoveToScrollbackTop") },
      { key = "G",          mods = "SHIFT", action = act.CopyMode("MoveToScrollbackBottom") },
      { key = "H",          mods = "SHIFT", action = act.CopyMode("MoveToViewportTop") },
      { key = "M",          mods = "SHIFT", action = act.CopyMode("MoveToViewportMiddle") },
      { key = "L",          mods = "SHIFT", action = act.CopyMode("MoveToViewportBottom") },
      { key = "u",          mods = "CTRL",  action = act.CopyMode({ MoveByPage = -0.5 }) },
      { key = "d",          mods = "CTRL",  action = act.CopyMode({ MoveByPage = 0.5 }) },
      { key = "b",          mods = "CTRL",  action = act.CopyMode("PageUp") },
      { key = "f",          mods = "CTRL",  action = act.CopyMode("PageDown") },
      { key = "v",          mods = "NONE",  action = act.CopyMode({ SetSelectionMode = "Cell" }) },
      { key = "V",          mods = "SHIFT", action = act.CopyMode({ SetSelectionMode = "Line" }) },
      { key = "v",          mods = "CTRL",  action = act.CopyMode({ SetSelectionMode = "Block" }) },
      { key = "o",          mods = "NONE",  action = act.CopyMode("MoveToSelectionOtherEnd") },
      { key = "/",          mods = "NONE",  action = act.Search({ CaseInSensitiveString = "" }) },
      { key = "n",          mods = "NONE",  action = act.CopyMode("NextMatch") },
      { key = "N",          mods = "SHIFT", action = act.CopyMode("PriorMatch") },
      {
        key = "y", mods = "NONE",
        action = act.Multiple({ { CopyTo = "ClipboardAndPrimarySelection" }, { CopyMode = "Close" } }),
      },
      {
        key = "Enter", mods = "NONE",
        action = act.Multiple({ { CopyTo = "ClipboardAndPrimarySelection" }, { CopyMode = "Close" } }),
      },
      { key = "LeftArrow",  mods = "NONE",  action = act.CopyMode("MoveLeft") },
      { key = "DownArrow",  mods = "NONE",  action = act.CopyMode("MoveDown") },
      { key = "UpArrow",    mods = "NONE",  action = act.CopyMode("MoveUp") },
      { key = "RightArrow", mods = "NONE",  action = act.CopyMode("MoveRight") },
    },

    search_mode = {
      { key = "Escape",     mods = "NONE",  action = act.CopyMode("Close") },
      { key = "Enter",      mods = "NONE",  action = act.CopyMode("PriorMatch") },
      { key = "n",          mods = "CTRL",  action = act.CopyMode("NextMatch") },
      { key = "p",          mods = "CTRL",  action = act.CopyMode("PriorMatch") },
      { key = "r",          mods = "CTRL",  action = act.CopyMode("CycleMatchType") },
      { key = "u",          mods = "CTRL",  action = act.CopyMode("ClearPattern") },
      { key = "PageUp",     mods = "NONE",  action = act.CopyMode("PriorMatchPage") },
      { key = "PageDown",   mods = "NONE",  action = act.CopyMode("NextMatchPage") },
      { key = "UpArrow",    mods = "NONE",  action = act.CopyMode("PriorMatch") },
      { key = "DownArrow",  mods = "NONE",  action = act.CopyMode("NextMatch") },
    },
  }

  return config
end

return M
