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
-- ─ Application ──────────────────────────────────────────────────────────
-- CTRL+SHIFT+P ........... Command palette
-- CTRL+SHIFT+L ........... Debug overlay
-- F11 ................... Toggle fullscreen
-- LEADER+F ............... Toggle fullscreen
-- CTRL+SHIFT+R ........... Reload config
-- CTRL+SHIFT+Q ........... Quit application
-- CTRL+SHIFT+N ........... New OS window
-- CTRL+SHIFT+= ........... Increase font size
-- CTRL+SHIFT+- ........... Decrease font size
-- CTRL+SHIFT+0 ........... Reset font size
-- LEADER+O ............... Cycle window opacity (1.0 → 0.95 → 0.85 → 0.75)
--
-- ─ Tabs ─────────────────────────────────────────────────────────────────
-- CTRL+SHIFT+T ........... New tab
-- CTRL+SHIFT+W ........... Close tab (with confirm)
-- CTRL+1 … CTRL+9 ........ Activate tab 1..9 (9 = last)
-- CTRL+SHIFT+] ........... Next tab
-- CTRL+SHIFT+[ ........... Prev tab
-- CTRL+SHIFT+RightArrow .. Move tab right
-- CTRL+SHIFT+LeftArrow ... Move tab left
-- LEADER+, ............... Rename current tab
--
-- ─ Panes ────────────────────────────────────────────────────────────────
-- LEADER+\ ............... Split right (split horizontal)
-- LEADER+| ............... Split right (alias, SHIFT+\)
-- LEADER+- ............... Split down  (split vertical)
-- LEADER+D ............... Close pane (with confirm)
-- LEADER+Z ............... Zoom toggle
-- CTRL+H, CTRL+J, CTRL+K, CTRL+L .. Move between panes (smart-splits, vim-aware)
-- META+H, META+J, META+K, META+L .. Resize panes (smart-splits, vim-aware)
-- LEADER+R ............... Resize-pane mode (hjkl or arrows; q/Enter exits)
-- LEADER+Space ........... Rotate panes clockwise
-- LEADER+! ............... Break pane into its own tab
-- LEADER+@ ............... Swap pane with another (visual picker)
--
-- ─ Workspaces ──────────────────────────────────────────────────────────
-- LEADER+S ............... Show workspace launcher (fuzzy)
-- LEADER+W ............... Rename current workspace
-- LEADER+N ............... Next workspace
-- LEADER+P ............... Prev workspace
--
-- ─ Copy and search ────────────────────────────────────────────────────────
-- CTRL+SHIFT+C ........... Copy to clipboard
-- CTRL+SHIFT+V ........... Paste from clipboard
-- LEADER+[ ............... Enter copy mode (vi-style; tmux-compatible)
-- LEADER+/ ............... Search
-- LEADER+Y ............... Quick-select (links, SHAs, etc.)
-- LEADER+U ............... Character picker
-- LEADER+K ............... Clear scrollback + viewport
--
-- ─ Domains (WSL, SSH) ────────────────────────────────────────
-- LEADER+G ............... Spawn into a WSL distro or SSH domain
--
-- ─ Sessions (resurrect.wezterm) ────────────────────────────
-- LEADER+A ............... Save current workspace snapshot to disk
-- LEADER+E ............... Fuzzy-load saved workspace, window, or tab
--
-- ─ Project workspaces (zoxide) ────────────────────────────
-- LEADER+J ............... Jump to a zoxide dir as a named workspace
--
-- ─ Tool overlays ─────────────────────────────────────────────
-- LEADER+X then G ........ Toggle lazygit overlay workspace
-- LEADER+X then T ........ Toggle btop overlay workspace
-- LEADER+X then N ........ Toggle navi overlay workspace
-- LEADER+X then O ........ Toggle opencode overlay workspace
--                         (same key returns to previous workspace)
--
-- ─ Broadcast ─────────────────────────────────────────────────
-- LEADER+B ............... Type a command, send to every pane in current tab
--
-- ─ Discovery ──────────────────────────────────────────────────
-- LEADER+? ............... Which-key style menu (fuzzy list of LEADER actions)

function M.apply_to_config(config)
  config.disable_default_key_bindings = true
  config.leader = { key = ";", mods = "CTRL", timeout_milliseconds = 1500 }

  -- ───────────────────────────────────────────────────────────────────────────
  -- smart-splits.nvim integration — seamless h/j/k/l between wezterm panes and
  -- nvim splits. Plugin sets IS_NVIM user var while nvim is active.
  -- ───────────────────────────────────────────────────────────────────────────
  -- Plugin is required for its side-effects; we just need the IS_NVIM detection.
  pcall(wezterm.plugin.require, "https://github.com/mrjones2014/smart-splits.nvim")

  -- ───────────────────────────────────────────────────────────────────────────
  -- resurrect.wezterm — session/workspace persistence to disk
  -- ───────────────────────────────────────────────────────────────────────────
  -- resurrect.wezterm creates its state dirs with os.execute("mkdir ...")
  -- during plugin init on Windows, which flashes transient cmd/conhost
  -- windows. If the plugin is already cached, register its module path and
  -- no-op only that helper before requiring the plugin. On a clean machine
  -- the plugin may not be cached yet; in that case skip suppression so the
  -- require below can clone it normally.
  if wezterm.target_triple:find("windows") then
    for _, plugin in ipairs(wezterm.plugin.list()) do
      local plugin_dir = plugin.plugin_dir or ""
      if plugin_dir:find("resurrect", 1, true) then
        package.path = package.path
          .. ";"
          .. plugin_dir
          .. "/plugin/?.lua"

        local ok_utils, resurrect_utils = pcall(require, "resurrect.utils")
        if ok_utils and resurrect_utils then
          resurrect_utils.ensure_folder_exists = function() end
        elseif wezterm.log_warn then
          wezterm.log_warn("Could not preload resurrect.utils; startup mkdir suppression skipped")
        end
        break
      end
    end
  end

  local ok_resurrect, resurrect = pcall(wezterm.plugin.require, "https://github.com/MLFlexer/resurrect.wezterm")
  if ok_resurrect then
    -- Auto-save the workspace state every 15 minutes.
    resurrect.state_manager.periodic_save({
      interval_seconds = 15 * 60,
      save_workspaces = true,
      save_windows = true,
      save_tabs = false,
    })
  end

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
  -- resurrect.wezterm save/load actions (LEADER+A / LEADER+E)
  -- ───────────────────────────────────────────────────────────────────────────
  local save_state = wezterm.action_callback(function(win, _)
    if not ok_resurrect then return end
    resurrect.state_manager.save_state(resurrect.workspace_state.get_workspace_state())
    win:toast_notification("resurrect", "workspace saved", nil, 2000)
  end)

  local load_state = wezterm.action_callback(function(win, pane)
    if not ok_resurrect then return end
    resurrect.fuzzy_loader.fuzzy_load(win, pane, function(id)
      local kind, file = id:match("^([^/]+)/(.+)$")
      if not kind or not file then return end
      file = file:gsub("%.json$", "")
      local opts = {
        window         = win:mux_window(),
        relative       = true,
        restore_text   = true,
        on_pane_restore = resurrect.tab_state.default_on_pane_restore,
      }
      if kind == "workspace" then
        local state = resurrect.state_manager.load_state(file, "workspace")
        resurrect.workspace_state.restore_workspace(state, opts)
      elseif kind == "window" then
        local state = resurrect.state_manager.load_state(file, "window")
        resurrect.window_state.restore_window(pane:window(), state, opts)
      elseif kind == "tab" then
        local state = resurrect.state_manager.load_state(file, "tab")
        resurrect.tab_state.restore_tab(pane:tab(), state, opts)
      end
    end)
  end)

  -- ───────────────────────────────────────────────────────────────────────────
  -- Zoxide project workspace picker (LEADER+J)
  -- Reads `zoxide query -l`, presents fuzzy selector, switches to a workspace
  -- named after the dir's basename, spawning the shell in that dir.
  -- ───────────────────────────────────────────────────────────────────────────
  local zoxide_workspace = wezterm.action_callback(function(win, pane)
    local handle = io.popen("zoxide query -l")
    if not handle then return end
    local out = handle:read("*a") or ""
    handle:close()

    local choices = {}
    for line in out:gmatch("[^\r\n]+") do
      if #line > 0 then table.insert(choices, { label = line }) end
    end
    if #choices == 0 then
      win:toast_notification("zoxide", "no entries", nil, 2000)
      return
    end

    win:perform_action(act.InputSelector({
      title = "  Project workspace (zoxide)",
      fuzzy = true,
      fuzzy_description = "  >  (Ctrl-C/G cancels) ",
      choices = choices,
      action = wezterm.action_callback(function(w, p, _, label)
        if not label then return end
        local name = label:match("[^\\/]+$") or label
        w:perform_action(act.SwitchToWorkspace({
          name  = name,
          spawn = { cwd = label },
        }), p)
      end),
    }), pane)
  end)

  -- ───────────────────────────────────────────────────────────────────────────
  -- Tool overlay workspaces (LEADER+X then g/t/n/o)
  -- Toggles between the tool's dedicated workspace and the previous one.
  -- ───────────────────────────────────────────────────────────────────────────
  local function toggle_overlay(ws_name, cmd_args)
    return wezterm.action_callback(function(win, pane)
      local current = wezterm.mux.get_active_workspace()
      if current == ws_name then
        local prev = wezterm.GLOBAL.prev_workspace or "default"
        win:perform_action(act.SwitchToWorkspace({ name = prev }), pane)
      else
        wezterm.GLOBAL.prev_workspace = current
        win:perform_action(act.SwitchToWorkspace({
          name  = ws_name,
          spawn = { args = cmd_args },
        }), pane)
      end
    end)
  end

  -- ───────────────────────────────────────────────────────────────────────────
  -- Broadcast a command to every pane in the current tab (LEADER+B)
  -- ───────────────────────────────────────────────────────────────────────────
  local broadcast = act.PromptInputLine({
    description = "Broadcast to all panes in tab:",
    action = wezterm.action_callback(function(_, pane, line)
      if not line or #line == 0 then return end
      local tab = pane:tab()
      if not tab then return end
      for _, p in ipairs(tab:panes()) do
        p:send_text(line .. "\r")
      end
    end),
  })

  -- ───────────────────────────────────────────────────────────────────────────
  -- Which-key menu (LEADER+?) — fuzzy-searchable popup of LEADER actions.
  -- Wezterm has no native which-key timed popup; this is the InputSelector
  -- idiom that gives equivalent discoverability.
  -- ───────────────────────────────────────────────────────────────────────────
  local wk_dispatch = {
    -- Application
    fullscreen     = act.ToggleFullScreen,
    opacity        = toggle_opacity,
    palette        = act.ActivateCommandPalette,
    reload         = act.ReloadConfiguration,

    -- Tabs
    tab_new        = act.SpawnTab("CurrentPaneDomain"),
    tab_close      = act.CloseCurrentTab({ confirm = true }),
    tab_rename     = rename_tab,
    tab_next       = act.ActivateTabRelative(1),
    tab_prev       = act.ActivateTabRelative(-1),

    -- Panes
    split_right    = act.SplitHorizontal({ domain = "CurrentPaneDomain" }),
    split_down     = act.SplitVertical({ domain = "CurrentPaneDomain" }),
    pane_close     = act.CloseCurrentPane({ confirm = true }),
    pane_zoom      = act.TogglePaneZoomState,
    pane_rotate    = act.RotatePanes("Clockwise"),
    pane_break     = act.PaneSelect({ mode = "MoveToNewTab" }),
    pane_swap      = act.PaneSelect({ mode = "SwapWithActive" }),
    pane_resize    = act.ActivateKeyTable({ name = "resize_pane", one_shot = false, timeout_milliseconds = 4000 }),

    -- Workspaces
    ws_launcher    = act.ShowLauncherArgs({ flags = "FUZZY|WORKSPACES" }),
    ws_rename      = rename_workspace,
    ws_next        = act.SwitchWorkspaceRelative(1),
    ws_prev        = act.SwitchWorkspaceRelative(-1),

    -- Copy / search
    copy_mode      = act.ActivateCopyMode,
    search         = act.Search({ CaseInSensitiveString = "" }),
    quick_select   = act.QuickSelect,
    char_select    = act.CharSelect({ copy_on_select = true, copy_to = "ClipboardAndPrimarySelection" }),
    clear          = act.ClearScrollback("ScrollbackAndViewport"),

    -- Domain launcher
    domain_launch  = act.ShowLauncherArgs({ flags = "FUZZY|DOMAINS" }),

    -- Sessions / projects / tools / broadcast
    rs_save        = save_state,
    rs_load        = load_state,
    zoxide_ws      = zoxide_workspace,
    tools_menu     = act.ActivateKeyTable({ name = "tools", one_shot = true, timeout_milliseconds = 2000 }),
    broadcast      = broadcast,
  }

  -- Display labels mirror the cheat sheet at the top of this file.
  -- Keep them aligned so the picker is grep-able / scannable.
  local wk_choices = {
    { label = "  App   fullscreen          F11 / LEADER+F",   id = "fullscreen" },
    { label = "  App   command palette     CTRL+SHIFT+P",     id = "palette" },
    { label = "  App   reload config       CTRL+SHIFT+R",     id = "reload" },
    { label = "  App   cycle opacity       LEADER+O",         id = "opacity" },

    { label = "  Tab   new                 CTRL+SHIFT+T",     id = "tab_new" },
    { label = "  Tab   close               CTRL+SHIFT+W",     id = "tab_close" },
    { label = "  Tab   rename              LEADER+,",         id = "tab_rename" },
    { label = "  Tab   next                CTRL+SHIFT+]",     id = "tab_next" },
    { label = "  Tab   prev                CTRL+SHIFT+[",     id = "tab_prev" },

    { label = "  Pane  split right         LEADER+\\",        id = "split_right" },
    { label = "  Pane  split down          LEADER+-",         id = "split_down" },
    { label = "  Pane  close               LEADER+D",         id = "pane_close" },
    { label = "  Pane  zoom toggle         LEADER+Z",         id = "pane_zoom" },
    { label = "  Pane  rotate              LEADER+SPACE",     id = "pane_rotate" },
    { label = "  Pane  break to new tab    LEADER+!",         id = "pane_break" },
    { label = "  Pane  swap with...        LEADER+@",         id = "pane_swap" },
    { label = "  Pane  resize mode         LEADER+R",         id = "pane_resize" },

    { label = "  WS    launcher            LEADER+S",         id = "ws_launcher" },
    { label = "  WS    rename current      LEADER+W",         id = "ws_rename" },
    { label = "  WS    next                LEADER+N",         id = "ws_next" },
    { label = "  WS    prev                LEADER+P",         id = "ws_prev" },

    { label = "  Copy  copy mode           LEADER+[",         id = "copy_mode" },
    { label = "  Copy  search              LEADER+/",         id = "search" },
    { label = "  Copy  quick select        LEADER+Y",         id = "quick_select" },
    { label = "  Copy  char picker         LEADER+U",         id = "char_select" },
    { label = "  Copy  clear scrollback    LEADER+K",         id = "clear" },

    { label = "  Dom   WSL / SSH launcher  LEADER+G",         id = "domain_launch" },

    { label = "  Sess  save workspace        LEADER+A",         id = "rs_save" },
    { label = "  Sess  load (fuzzy)          LEADER+E",         id = "rs_load" },

    { label = "  Proj  zoxide workspace      LEADER+J",         id = "zoxide_ws" },

    { label = "  Tool  open overlay (g/t/n/o) LEADER+X",         id = "tools_menu" },

    { label = "  Bcst  send cmd to all panes LEADER+B",         id = "broadcast" },
  }

  local which_key = act.InputSelector({
    title = "  Which-key  (LEADER actions — type to filter)",
    description = "  Enter = accept, Ctrl-C/Ctrl-G = cancel, / = filter",
    fuzzy_description = "  >  (Ctrl-C/G cancels) ",
    choices = wk_choices,
    action = wezterm.action_callback(function(win, pane, _, label)
      if not label then return end
      -- find the choice with this label, then dispatch by id
      for _, c in ipairs(wk_choices) do
        if c.label == label and wk_dispatch[c.id] then
          win:perform_action(wk_dispatch[c.id], pane)
          return
        end
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
    { key = "{",          mods = "CTRL|SHIFT",  action = act.ActivateTabRelative(-1) },
    { key = "}",          mods = "CTRL|SHIFT",  action = act.ActivateTabRelative(1) },
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

    -- ── Sessions (resurrect.wezterm) ─────────────────────────
    { key = "a",          mods = "LEADER",      action = save_state },
    { key = "e",          mods = "LEADER",      action = load_state },

    -- ── Project workspaces (zoxide) ─────────────────────────
    { key = "j",          mods = "LEADER",      action = zoxide_workspace },

    -- ── Tool overlays (LEADER+X then g/t/n/o) ────────────────────
    {
      key = "x", mods = "LEADER",
      action = act.ActivateKeyTable({ name = "tools", one_shot = true, timeout_milliseconds = 2000 }),
    },

    -- ── Broadcast ───────────────────────────────────────────────
    { key = "b",          mods = "LEADER",      action = broadcast },

    -- ── Discovery / which-key ────────────────────────────────
    { key = "?",          mods = "LEADER|SHIFT", action = which_key },
  }

  -- ───────────────────────────────────────────────────────────────────────────
  -- Key tables (modal modes)
  -- ───────────────────────────────────────────────────────────────────────────
  config.key_tables = {
    -- LEADER+R → mash hjkl/arrows; q/Enter exits.
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

    -- LEADER+X then g/t/n/o — spawn (or return from) a tool's dedicated workspace.
    tools = {
      { key = "g",      mods = "NONE", action = toggle_overlay("lazygit",  { "pwsh.exe", "-NoLogo", "-NoProfile", "-Command", "lazygit" }) },
      { key = "t",      mods = "NONE", action = toggle_overlay("btop",     { "pwsh.exe", "-NoLogo", "-NoProfile", "-Command", "btop" }) },
      { key = "n",      mods = "NONE", action = toggle_overlay("navi",     { "pwsh.exe", "-NoLogo", "-NoProfile", "-Command", "navi" }) },
      { key = "o",      mods = "NONE", action = toggle_overlay("opencode", { "pwsh.exe", "-NoLogo", "-NoProfile", "-Command", "opencode" }) },
      { key = "Escape", mods = "NONE", action = "PopKeyTable" },
      { key = "q",      mods = "NONE", action = "PopKeyTable" },
    },

    search_mode = {
      { key = "Escape",     mods = "NONE",  action = act.CopyMode("Close") },
      { key = "Enter",      mods = "NONE",  action = act.CopyMode("PriorMatch") },
      { key = "q",          mods = "NONE",  action = act.CopyMode("Close") },
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
