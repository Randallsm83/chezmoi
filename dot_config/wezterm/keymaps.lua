local wezterm = require("wezterm")
local act = wezterm.action
local M = {}

function M.apply_to_config(config)
  config.enable_kitty_keyboard = true
  config.disable_default_key_bindings = true
  config.leader = { key = ";", mods = "CTRL", timeout_milliseconds = 1000 }

  -- Pane/Split Nav
  local smart_splits = wezterm.plugin.require("http://github.com/mrjones2014/smart-splits.nvim")

  local function is_vim(pane)
    -- this is set by the plugin, and unset on ExitPre in Neovim
    return pane:get_user_vars().IS_NVIM == 'true'
  end

  local direction_keys = {
    h = 'Left',
    j = 'Down',
    k = 'Up',
    l = 'Right',
  }

  local function split_nav(resize_or_move, key)
    return {
      key = key,
      mods = resize_or_move == 'resize' and 'META' or 'CTRL',
      action = wezterm.action_callback(function(win, pane)
        if is_vim(pane) then
          -- pass the keys through to vim/nvim
          win:perform_action({
            SendKey = { key = key, mods = resize_or_move == 'resize' and 'META' or 'CTRL' },
          }, pane)
        else
          if resize_or_move == 'resize' then
            win:perform_action({ AdjustPaneSize = { direction_keys[key], 3 } }, pane)
          else
            win:perform_action({ ActivatePaneDirection = direction_keys[key] }, pane)
          end
        end
      end),
    }
  end

  config.keys = {
    --------------------------------- Tabs ---------------------------------
    -- New Tab
    { key = "t", mods = "SUPER", action = act.SpawnTab("CurrentPaneDomain") },

    -- Close Tab
    { key = "w", mods = "SUPER", action = act.CloseCurrentTab({ confirm = true }) },

    -- Activate a Tab (CTRL to match Warp/VS Code)
    { key = "1", mods = "CTRL", action = act.ActivateTab(0) },
    { key = "2", mods = "CTRL", action = act.ActivateTab(1) },
    { key = "3", mods = "CTRL", action = act.ActivateTab(2) },
    { key = "4", mods = "CTRL", action = act.ActivateTab(3) },
    { key = "5", mods = "CTRL", action = act.ActivateTab(4) },
    { key = "6", mods = "CTRL", action = act.ActivateTab(5) },
    { key = "7", mods = "CTRL", action = act.ActivateTab(6) },
    { key = "8", mods = "CTRL", action = act.ActivateTab(7) },
    { key = "9", mods = "CTRL", action = act.ActivateTab(-1) },

    -- Move Through Tabs (CTRL+SHIFT to match Warp)
    { key = "[", mods = "CTRL|SHIFT", action = act.ActivateTabRelative(-1) },
    { key = "]", mods = "CTRL|SHIFT", action = act.ActivateTabRelative(1) },

    --------------------------------- Panes --------------------------------
    -- Toggle Pane Zoom (LEADER + CTRL+SHIFT to match Warp pane_group:toggle_maximize_pane)
    { key = "z", mods = "LEADER", action = act.TogglePaneZoomState },
    { key = "z", mods = "CTRL|SHIFT", action = act.TogglePaneZoomState },

    -- Split Panes (LEADER + CTRL+SHIFT to match Warp pane_group:add_*)
    { key = "d", mods = "LEADER", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
    { key = "e", mods = "LEADER", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
    { key = "d", mods = "CTRL|SHIFT", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
    { key = "e", mods = "CTRL|SHIFT", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },

    -- Move Through Panes
    -- Handled by smart-splits
    -- { key = "h", mods = "LEADER", action = act.ActivatePaneDirection("Left") },
    -- { key = "l", mods = "LEADER", action = act.ActivatePaneDirection("Right") },
    -- { key = "k", mods = "LEADER", action = act.ActivatePaneDirection("Up") },
    -- { key = "j", mods = "LEADER", action = act.ActivatePaneDirection("Down") },
    -- { key = "h", mods = "CTRL", action = act.ActivatePaneDirection("Left") },
    -- { key = "l", mods = "CTRL", action = act.ActivatePaneDirection("Right") },
    -- { key = "k", mods = "CTRL", action = act.ActivatePaneDirection("Up") },
    -- { key = "j", mods = "CTRL", action = act.ActivatePaneDirection("Down") },
    split_nav('move', 'h'),
    split_nav('move', 'j'),
    split_nav('move', 'k'),
    split_nav('move', 'l'),

    -- Adjust Pane Size
    -- { key = "h", mods = "LEADER|ALT", action = act.AdjustPaneSize({ "Left", 5 }) },
    -- { key = "l", mods = "LEADER|ALT", action = act.AdjustPaneSize({ "Right", 5 }) },
    -- { key = "k", mods = "LEADER|ALT", action = act.AdjustPaneSize({ "Up", 5 }) },
    -- { key = "j", mods = "LEADER|ALT", action = act.AdjustPaneSize({ "Down", 5 }) },
    split_nav('resize', 'h'),
    split_nav('resize', 'j'),
    split_nav('resize', 'k'),
    split_nav('resize', 'l'),

    -------------------------------- Application ---------------------------
    -- Toggle Fullscreen (F11 matches Warp view:toggle_fullscreen)
    { key = "Enter", mods = "SUPER", action = act.ToggleFullScreen },
    { key = "Enter", mods = "LEADER", action = act.ToggleFullScreen },
    { key = "F11", mods = "NONE", action = act.ToggleFullScreen },

    -- Search
    { key = "/", mods = "SUPER", action = act.Search("CurrentSelectionOrEmptyString") },
    { key = "/", mods = "LEADER", action = act.Search({ CaseInSensitiveString = "" }) },

    -- Clear Scrollback
    { key = "b", mods = "SUPER", action = act.ClearScrollback("ScrollbackOnly") },
    { key = "b", mods = "LEADER", action = act.ClearScrollback("ScrollbackOnly") },

    -- Spawn Window
    { key = "n", mods = "SUPER", action = act.SpawnWindow },
    { key = "n", mods = "LEADER", action = act.SpawnWindow },

    -- Quit App
    { key = "q", mods = "SUPER", action = act.QuitApplication },
    { key = "q", mods = "LEADER", action = act.QuitApplication },

    -- Reload Config
    { key = "r", mods = "SUPER", action = act.ReloadConfiguration },
    { key = "r", mods = "LEADER", action = act.ReloadConfiguration },

    -- Copy And Paste
    { key = "c", mods = "SUPER", action = act.CopyTo("Clipboard") },
    { key = "c", mods = "LEADER", action = act.CopyTo("Clipboard") },
    { key = "v", mods = "SUPER", action = act.PasteFrom("Clipboard") },
    { key = "v", mods = "LEADER", action = act.PasteFrom("Clipboard") },
    { key = "x", mods = "LEADER", action = act.ActivateCopyMode },
    { key = "Copy", mods = "NONE", action = act.CopyTo("Clipboard") },
    { key = "Paste", mods = "NONE", action = act.PasteFrom("Clipboard") },

    -- Show Workspaces
    { key = "s", mods = "LEADER", action = act.ShowLauncherArgs({ flags = "WORKSPACES" }) },

    -- CharSelect
    {
      key = "u",
      mods = "LEADER",
      action = act.CharSelect({ copy_on_select = true, copy_to = "ClipboardAndPrimarySelection" }),
    },

    -- QuickSelect
    { key = "phys:Space", mods = "LEADER", action = act.QuickSelect },

    -- Command Palette and Debug Overlay
    { key = "l", mods = "SHIFT|SUPER", action = act.ShowDebugOverlay },
    { key = "p", mods = "SHIFT|SUPER", action = act.ActivateCommandPalette },

    -- Font Size
    { key = "0", mods = "SUPER", action = act.ResetFontSize },
    { key = "=", mods = "SUPER", action = act.IncreaseFontSize },
    { key = "-", mods = "SUPER", action = act.DecreaseFontSize },
  }

  config.key_tables = {
    copy_mode = {
      { key = "Tab", mods = "NONE", action = act.CopyMode("MoveForwardWord") },
      { key = "Tab", mods = "SHIFT", action = act.CopyMode("MoveBackwardWord") },
      { key = "Enter", mods = "NONE", action = act.CopyMode("MoveToStartOfNextLine") },
      { key = "Escape", mods = "NONE", action = act.CopyMode("Close") },
      { key = "Space", mods = "NONE", action = act.CopyMode({ SetSelectionMode = "Cell" }) },
      { key = "$", mods = "NONE", action = act.CopyMode("MoveToEndOfLineContent") },
      { key = "$", mods = "SHIFT", action = act.CopyMode("MoveToEndOfLineContent") },
      { key = ",", mods = "NONE", action = act.CopyMode("JumpReverse") },
      { key = "0", mods = "NONE", action = act.CopyMode("MoveToStartOfLine") },
      { key = ";", mods = "NONE", action = act.CopyMode("JumpAgain") },
      { key = "F", mods = "NONE", action = act.CopyMode({ JumpBackward = { prev_char = false } }) },
      { key = "F", mods = "SHIFT", action = act.CopyMode({ JumpBackward = { prev_char = false } }) },
      { key = "G", mods = "NONE", action = act.CopyMode("MoveToScrollbackBottom") },
      { key = "G", mods = "SHIFT", action = act.CopyMode("MoveToScrollbackBottom") },
      { key = "H", mods = "NONE", action = act.CopyMode("MoveToViewportTop") },
      { key = "H", mods = "SHIFT", action = act.CopyMode("MoveToViewportTop") },
      { key = "L", mods = "NONE", action = act.CopyMode("MoveToViewportBottom") },
      { key = "L", mods = "SHIFT", action = act.CopyMode("MoveToViewportBottom") },
      { key = "M", mods = "NONE", action = act.CopyMode("MoveToViewportMiddle") },
      { key = "M", mods = "SHIFT", action = act.CopyMode("MoveToViewportMiddle") },
      { key = "O", mods = "NONE", action = act.CopyMode("MoveToSelectionOtherEndHoriz") },
      { key = "O", mods = "SHIFT", action = act.CopyMode("MoveToSelectionOtherEndHoriz") },
      { key = "T", mods = "NONE", action = act.CopyMode({ JumpBackward = { prev_char = true } }) },
      { key = "T", mods = "SHIFT", action = act.CopyMode({ JumpBackward = { prev_char = true } }) },
      { key = "V", mods = "NONE", action = act.CopyMode({ SetSelectionMode = "Line" }) },
      { key = "V", mods = "SHIFT", action = act.CopyMode({ SetSelectionMode = "Line" }) },
      { key = "^", mods = "NONE", action = act.CopyMode("MoveToStartOfLineContent") },
      { key = "^", mods = "SHIFT", action = act.CopyMode("MoveToStartOfLineContent") },
      { key = "b", mods = "NONE", action = act.CopyMode("MoveBackwardWord") },
      { key = "b", mods = "ALT", action = act.CopyMode("MoveBackwardWord") },
      { key = "b", mods = "CTRL", action = act.CopyMode("PageUp") },
      { key = "c", mods = "CTRL", action = act.CopyMode("Close") },
      { key = "d", mods = "CTRL", action = act.CopyMode({ MoveByPage = 0.5 }) },
      { key = "e", mods = "NONE", action = act.CopyMode("MoveForwardWordEnd") },
      { key = "f", mods = "NONE", action = act.CopyMode({ JumpForward = { prev_char = false } }) },
      { key = "f", mods = "ALT", action = act.CopyMode("MoveForwardWord") },
      { key = "f", mods = "CTRL", action = act.CopyMode("PageDown") },
      { key = "g", mods = "NONE", action = act.CopyMode("MoveToScrollbackTop") },
      { key = "g", mods = "CTRL", action = act.CopyMode("Close") },
      { key = "h", mods = "NONE", action = act.CopyMode("MoveLeft") },
      { key = "j", mods = "NONE", action = act.CopyMode("MoveDown") },
      { key = "k", mods = "NONE", action = act.CopyMode("MoveUp") },
      { key = "l", mods = "NONE", action = act.CopyMode("MoveRight") },
      { key = "m", mods = "ALT", action = act.CopyMode("MoveToStartOfLineContent") },
      { key = "o", mods = "NONE", action = act.CopyMode("MoveToSelectionOtherEnd") },
      { key = "q", mods = "NONE", action = act.CopyMode("Close") },
      { key = "t", mods = "NONE", action = act.CopyMode({ JumpForward = { prev_char = true } }) },
      { key = "u", mods = "CTRL", action = act.CopyMode({ MoveByPage = -0.5 }) },
      { key = "v", mods = "NONE", action = act.CopyMode({ SetSelectionMode = "Cell" }) },
      { key = "v", mods = "CTRL", action = act.CopyMode({ SetSelectionMode = "Block" }) },
      { key = "w", mods = "NONE", action = act.CopyMode("MoveForwardWord") },
      {
        key = "y",
        mods = "NONE",
        action = act.Multiple({ { CopyTo = "ClipboardAndPrimarySelection" }, { CopyMode = "Close" } }),
      },
      { key = "LeftArrow", mods = "NONE", action = act.CopyMode("MoveLeft") },
      { key = "LeftArrow", mods = "ALT", action = act.CopyMode("MoveBackwardWord") },
      { key = "RightArrow", mods = "NONE", action = act.CopyMode("MoveRight") },
      { key = "RightArrow", mods = "ALT", action = act.CopyMode("MoveForwardWord") },
      { key = "UpArrow", mods = "NONE", action = act.CopyMode("MoveUp") },
      { key = "DownArrow", mods = "NONE", action = act.CopyMode("MoveDown") },
    },
    search_mode = {
      { key = "Enter", mods = "NONE", action = act.CopyMode("PriorMatch") },
      { key = "Escape", mods = "NONE", action = act.CopyMode("Close") },
      { key = "n", mods = "CTRL", action = act.CopyMode("NextMatch") },
      { key = "p", mods = "CTRL", action = act.CopyMode("PriorMatch") },
      { key = "r", mods = "CTRL", action = act.CopyMode("CycleMatchType") },
      { key = "u", mods = "CTRL", action = act.CopyMode("ClearPattern") },
      { key = "PageUp", mods = "NONE", action = act.CopyMode("PriorMatchPage") },
      { key = "PageDown", mods = "NONE", action = act.CopyMode("NextMatchPage") },
      { key = "UpArrow", mods = "NONE", action = act.CopyMode("PriorMatch") },
      { key = "DownArrow", mods = "NONE", action = act.CopyMode("NextMatch") },
    },
  }

  return config
end

return M
