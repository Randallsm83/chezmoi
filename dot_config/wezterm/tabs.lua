-- ██╗    ██╗███████╗███████╗████████╗███████╗██████╗ ███╗   ███╗
-- ██║    ██║██╔════╝╚══███╔╝╚══██╔══╝██╔════╝██╔══██╗████╗ ████║
-- ██║ █╗ ██║█████╗    ███╔╝    ██║   █████╗  ██████╔╝██╔████╔██║
-- ██║███╗██║██╔══╝   ███╔╝     ██║   ██╔══╝  ██╔══██╗██║╚██╔╝██║
-- ╚███╔███╔╝███████╗███████╗   ██║   ███████╗██║  ██║██║ ╚═╝ ██║
--  ╚══╝╚══╝ ╚══════╝╚══════╝   ╚═╝   ╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝
-- GPU-accelerated cross-platform terminal emulator.
--

---@diagnostic disable: undefined-field

local wezterm = require("wezterm")
local M = {}

-- Status bar icons
local ICONS = {
  left_hard = wezterm.nerdfonts.pl_left_hard_divider,
  left_soft = wezterm.nerdfonts.pl_left_soft_divider,
  right_hard = wezterm.nerdfonts.pl_right_hard_divider,
  right_soft = wezterm.nerdfonts.pl_right_soft_divider,
  honeycomb = wezterm.nerdfonts.ple_honeycomb,
  honeycomb_outlne = wezterm.nerdfonts.ple_honeycomb_outline,
  arrow = wezterm.nerdfonts.fa_long_arrow_right,
  field = wezterm.nerdfonts.indent_line,
  workspace = wezterm.nerdfonts.cod_window,
  dir = wezterm.nerdfonts.oct_file_directory,
  clock = wezterm.nerdfonts.md_calendar_clock,
  user = wezterm.nerdfonts.fa_user,
  host = wezterm.nerdfonts.md_at,
  hourglass = wezterm.nerdfonts.fa_hourglass,
  dev_terminal = wezterm.nerdfonts.dev_terminal,
  fa_terminal = wezterm.nerdfonts.fa_terminal,
  oct_terminal = wezterm.nerdfonts.fa_terminal,
  tab = wezterm.nerdfonts.oct_tab,
  copy = wezterm.nerdfonts.oct_copy,
  resize = wezterm.nerdfonts.oct_arrow_up_right,
  leader = wezterm.nerdfonts.oct_rocket,
  search = wezterm.nerdfonts.cod_search,
}

-- Process-specific icons
local PROCESS_ICONS = {
  ["debug"] = wezterm.nerdfonts.cod_debug_console,
  ["zsh"] = wezterm.nerdfonts.oct_terminal,
  ["bash"] = wezterm.nerdfonts.cod_terminal_bash,
  ["fish"] = wezterm.nerdfonts.dev_terminal,
  ["term"] = wezterm.nerdfonts.dev_terminal,
  ["ssh"] = wezterm.nerdfonts.cod_terminal_linux,
  ["sudo"] = wezterm.nerdfonts.fa_hashtag,
  ["kuberlr"] = wezterm.nerdfonts.linux_docker,
  ["kubectl"] = wezterm.nerdfonts.linux_docker,
  ["make"] = wezterm.nerdfonts.seti_makefile,
  ["htop"] = wezterm.nerdfonts.mdi_chart_donut_variant,
  ["vim"] = wezterm.nerdfonts.custom_vim,
  ["nvim"] = wezterm.nerdfonts.custom_vim,
  ["git"] = wezterm.nerdfonts.dev_git,
  ["wget"] = wezterm.nerdfonts.mdi_arrow_down_box,
  ["curl"] = wezterm.nerdfonts.mdi_flattr,
  ["gh"] = wezterm.nerdfonts.dev_github_badge,
  ["node"] = wezterm.nerdfonts.dev_nodejs_small,
  ["perl"] = wezterm.nerdfonts.dev_perl,
  ["python"] = wezterm.nerdfonts.dev_python,
  ["lua"] = wezterm.nerdfonts.seti_lua,
  ["go"] = wezterm.nerdfonts.seti_go,
  ["cargo"] = wezterm.nerdfonts.dev_rust,
  ["ruby"] = wezterm.nerdfonts.cod_ruby,
  ["ls"] = wezterm.nerdfonts.cod_list_tree,
  ["eza"] = wezterm.nerdfonts.cod_list_tree,
  ["docker"] = wezterm.nerdfonts.linux_docker,
}

local function get_process_icon(process)
  return PROCESS_ICONS[process] or ICONS.oct_terminal
end

local function basename(s)
  if type(s) ~= "string" then
    return nil
  end
  return string.gsub(s, "(.*[/\\])(.*)", "%2")
end

wezterm.on("format-tab-title", function(tab, tabs, _, conf)
  local index = tab.tab_index + 1
  local pane = tab.active_pane
  local process = basename(pane.foreground_process_name)
  local icon = get_process_icon(process)
  local host = wezterm.hostname()
  local ssh = pane.domain_name:match("^SSH[%w]*:(.+)$")
  if ssh then
    host = ssh
    process = "ssh"
    icon = get_process_icon(process)
  end

  -- Show activity marker for inactive tabs with unseen output
  -- if not tab.is_active and active_pane.has_unseen_output then
  -- print(wez.nerdfonts.cod_circled_filled  .. formatted_title)
  -- end

  local formatted_title = string.format("%s ", process)

  local width = conf.tab_max_width - 4
  if #formatted_title > conf.tab_max_width then
    formatted_title = wezterm.truncate_right(formatted_title, width) .. "…"
  end

  -- print(conf)
  local palette = conf.resolved_palette
  -- print(palette)

  local colors = {
  --  MEDIUM MIX
    -- tab_fg = tab.is_active and wezterm.color.parse(palette.ansi[3]) or wezterm.color.parse(palette.foreground),
    --
    -- fg0 = wezterm.color.parse("#e2cca9"),
    -- fg1 = wezterm.color.parse("#e2cca9"),
    -- red = wezterm.color.parse("#f2594b"),
    -- green = wezterm.color.parse("#b0b846"),
    -- yellow = wezterm.color.parse("#e9b143"),
    -- blue = wezterm.color.parse("#80aa9e"),
    -- purple = wezterm.color.parse("#d3869b"),
    --    cyan = wezterm.color.parse("#8bba7f"),
    -- orange = wezterm.color.parse("#f28534"),
    -- bg_red = wezterm.color.parse("#db4740"),
    -- bg_green = wezterm.color.parse("#b0b846"),
    -- bg_yellow = wezterm.color.parse("#e9b143"),
    --
    -- bg_dim = wezterm.color.parse("#1b1b1b"),
    -- bg0 = wezterm.color.parse("#282828"),
    -- bg1 = wezterm.color.parse("#32302f"),
    -- bg2 = wezterm.color.parse("#32302f"),
    -- bg3 = wezterm.color.parse("#45403d"),
    -- bg4 = wezterm.color.parse("#45403d"),
    -- bg5 = wezterm.color.parse("#5a524c"),
    -- bg_statusline1 = wezterm.color.parse("#32302f"),
    -- bg_statusline2 = wezterm.color.parse("#3a3735"),
    -- bg_statusline3 = wezterm.color.parse("#504945"),
    -- bg_diff_green = wezterm.color.parse("#34381b"),
    -- bg_visual_green = wezterm.color.parse("#3b4439"),
    -- bg_diff_red = wezterm.color.parse("#402120"),
    -- bg_visual_red = wezterm.color.parse("#4c3432"),
    -- bg_diff_blue = wezterm.color.parse("#0e363e"),
    -- bg_visual_blue = wezterm.color.parse("#374141"),
    -- bg_visual_yellow = wezterm.color.parse("#4f422e"),
    -- bg_current_word = wezterm.color.parse("#3c3836"),

    -- DARK MEDIUM BG
    bg_dim           = wezterm.color.parse('#1b1b1b'),
    bg0              = wezterm.color.parse('#282828'),
    bg1              = wezterm.color.parse('#32302f'),
    bg2              = wezterm.color.parse('#32302f'),
    bg3              = wezterm.color.parse('#45403d'),
    bg4              = wezterm.color.parse('#45403d'),
    bg5              = wezterm.color.parse('#5a524c'),
    bg_statusline1   = wezterm.color.parse('#32302f'),
    bg_statusline2   = wezterm.color.parse('#3a3735'),
    bg_statusline3   = wezterm.color.parse('#504945'),
    bg_diff_green    = wezterm.color.parse('#34381b'),
    bg_visual_green  = wezterm.color.parse('#3b4439'),
    bg_diff_red      = wezterm.color.parse('#402120'),
    bg_visual_red    = wezterm.color.parse('#4c3432'),
    bg_diff_blue     = wezterm.color.parse('#0e363e'),
    bg_visual_blue   = wezterm.color.parse('#374141'),
    bg_visual_yellow = wezterm.color.parse('#4f422e'),
    bg_current_word  = wezterm.color.parse( '#3c3836'),

    -- DARK MATERIAL FG
    fg0        = wezterm.color.parse('#d4be98'),
    fg1        = wezterm.color.parse('#ddc7a1'),
    red        = wezterm.color.parse('#ea6962'),
    orange     = wezterm.color.parse('#e78a4e'),
    yellow     = wezterm.color.parse('#d8a657'),
    green      = wezterm.color.parse('#a9b665'),
    aqua       = wezterm.color.parse('#89b482'),
    blue       = wezterm.color.parse('#7daea3'),
    purple     = wezterm.color.parse('#d3869b'),
    bg_red     = wezterm.color.parse('#ea6962'),
    bg_green   = wezterm.color.parse('#a9b665'),
    bg_yellow  = wezterm.color.parse('#d8a657'),
    -- fg0 = wezterm.color.parse(palette.ansi[8]),
    -- fg1 = wezterm.color.parse("ddc7a1"),
    -- bg0 = wezterm.color.parse("#282828"),
    -- bg1 = wezterm.color.parse("#32302f"),
    -- bg2 = wezterm.color.parse("#45403d"),
    -- bg3 = wezterm.color.parse("#5a524c"),
    -- tab_bg1 = wezterm.color.parse("#32302f"),
    -- tab_bg2 = wezterm.color.parse("#3a3735"),
    -- tab_bg3 = wezterm.color.parse("#504945"),
    -- grey = wezterm.color.parse(palette.ansi[1]),
    -- red = wezterm.color.parse(palette.ansi[2]),
    -- green = wezterm.color.parse(palette.ansi[3]),
    -- yellow = wezterm.color.parse(palette.ansi[4]),
    -- blue = wezterm.color.parse(palette.ansi[5]),
    -- purple = wezterm.color.parse(palette.ansi[6]),
    -- cyan = wezterm.color.parse(palette.ansi[7]),
    -- white = wezterm.color.parse(palette.ansi[8]),
    -- orange = wezterm.color.parse("#e78a4e"),

    -- DARK MIX FG
  }

  colors.tab_fg = tab.is_active and colors.fg0 or colors.fg0:darken(.1)
  colors.tab_bg = tab.is_active and colors.bg2:lighten(.1) or colors.bg2:darken(.1)
  colors.separator_bg = tab.is_active and colors.bg2:darken(.1) or colors.bg2:lighten(.1)

  if index == 1 then
    -- First tab
    return {
        { Background = { Color = colors.tab_bg } },
        -- { Foreground = { Color = colors.green:saturate(.1) } },
        { Foreground = { Color = colors.fg0:darken(.2) } },
        { Text = string.format("%s ", ICONS.left_hard) },
        { Text = string.format("%s ", icon) },
        { Text = formatted_title },
        { Foreground = { Color = colors.orange } },
        { Text = string.format("[", host) },
        { Foreground = { Color = colors.tab_fg } },
        { Text = string.format("%s", host) },
        { Foreground = { Color = colors.orange } },
        { Text = string.format("] ", host) },
        { Foreground = { Color = colors.tab_bg } },
        { Background = { Color = colors.separator_bg } },
        { Text = string.format("%s ", ICONS.left_hard) },
    }
  elseif index < #tabs then
    -- Middle tabs
    return {
        { Background = { Color = colors.tab_bg } },
        { Foreground = { Color = colors.tab_bg } },
        { Text = string.format("%s ", ICONS.left_hard) },
        { Foreground = { Color = colors.green:saturate(.1) } },
        { Text = string.format("%s ", icon) },
        { Foreground = { Color = colors.tab_fg } },
        { Text = formatted_title },
        { Foreground = { Color = colors.orange } },
        { Text = string.format("[", host) },
        { Foreground = { Color = colors.tab_fg } },
        { Text = string.format("%s", host) },
        { Foreground = { Color = colors.orange } },
        { Text = string.format("] ", host) },
        { Background = { Color = colors.separator_bg } },
    }
  else
    -- Last tab
  end

  -- if index < #tabs then
  --   return {
  --     { Background = { Color = colors.tab_bg } },
  --     { Foreground = { Color = colors.green:saturate(.1) } },
  --     { Text = string.format("%s ", icon) },
  --     { Foreground = { Color = colors.tab_fg } },
  --     { Text = formatted_title },
  --     { Foreground = { Color = colors.orange } },
  --     { Text = string.format("[", host) },
  --     { Foreground = { Color = colors.tab_fg } },
  --     { Text = string.format("%s", host) },
  --     { Foreground = { Color = colors.orange } },
  --     { Text = string.format("] ", host) },
  --     { Foreground = { Color = colors.tab_bg } },
  --     { Background = { Color = colors.separator_bg } },
  --     { Text = string.format("%s ", ICONS.left_hard) },
  --   }
  -- end
  -- return {
  --   { Background = { Color = colors.tab_bg } },
  --   { Foreground = { Color = colors.green:saturate(.1) } },
  --   { Text = string.format("%s ", icon) },
  --   { Foreground = { Color = colors.tab_fg } },
  --   { Text = formatted_title },
  --   { Foreground = { Color = colors.orange } },
  --   { Text = string.format("[", host) },
  --   { Foreground = { Color = colors.tab_fg } },
  --   { Text = string.format("%s", host) },
  --   { Foreground = { Color = colors.orange } },
  --   { Text = string.format("] ", host) },
  --   { Background = { Color = colors.bg0 } },
  --   { Foreground = { Color = colors.tab_bg } },
  --   { Text = string.format("%s ", ICONS.left_hard) },
  -- }
  --   return {
  --     { Background = { Color = colors.tab_bg } },
  --     { Foreground = { Color = colors.green:saturate(.1) } },
  --     { Text = string.format("%s ", icon) },
  --     { Foreground = { Color = colors.tab_fg } },
  --     { Text = formatted_title },
  --     { Foreground = { Color = colors.orange } },
  --     { Text = string.format("[", host) },
  --     { Foreground = { Color = colors.tab_fg } },
  --     { Text = string.format("%s", host) },
  --     { Foreground = { Color = colors.orange } },
  --     { Text = string.format("] ", host) },
  --     { Foreground = { Color = colors.fg0:lighten(.4) } },
  --     { Background = { Color = colors.separator_bg } },
  --     { Text = string.format("%s ", ICONS.left_soft) },
  --   }
  --
end)

wezterm.on("update-status", function(window, pane)
  local palette = window:effective_config().resolved_palette
  local colors = {
    fg = wezterm.color.parse(palette.foreground),
    dark_bg = wezterm.color.parse(palette.background),
    light_bg = wezterm.color.parse(palette.ansi[1]),
    red = wezterm.color.parse(palette.ansi[2]),
    green = wezterm.color.parse(palette.ansi[3]),
    yellow = wezterm.color.parse(palette.ansi[4]),
    blue = wezterm.color.parse(palette.ansi[5]),
    pink = wezterm.color.parse(palette.ansi[6]),
    cyan = wezterm.color.parse(palette.ansi[7]),
    white = wezterm.color.parse(palette.ansi[8]),
    orange = wezterm.color.parse("#d65d0e"),
    other_bg = wezterm.color.parse("#665c54"),
  }

  -- TODO: figure out quick select, debug and command palette modes? emit events?
  local status_settings = {
    normal = {
      icon = ICONS.fa_terminal,
      color = colors.fg:desaturate(0.6):darken(0.2),
      text = "NORMAL",
    },
    leader = {
      icon = ICONS.leader,
      color = colors.pink:saturate(0.25),
      text = "LEADER",
    },
    copy_mode = {
      icon = ICONS.copy,
      color = colors.blue,
      text = " COPY ",
    },
    search_mode = {
      icon = ICONS.search,
      color = colors.cyan,
      text = "SEARCH",
    },
    resize_pane = {
      icon = ICONS.resize,
      color = colors.cyan,
      text = "RESIZE",
    },
    move_tab = {
      icon = ICONS.tab,
      color = colors.cyan,
      text = " MOVE ",
    },
  }

  local status = "normal"
  if window:active_key_table() then
    status = window:active_key_table()
  elseif window:leader_is_active() then
    status = "leader"
  end

  -- Left status
  local left_status = {}

  -- Mode status
  table.insert(left_status, { Foreground = { Color = colors.dark_bg } })
  table.insert(left_status, { Background = { Color = status_settings[status].color } })
  table.insert(left_status, { Attribute = { Intensity = "Bold" } })
  table.insert(left_status, { Text = string.format(" %s ", status_settings[status].text) })
  table.insert(left_status, { Foreground = { Color = status_settings[status].color } })
  table.insert(left_status, { Background = { Color = colors.other_bg:darken(0.2) } })
  table.insert(left_status, { Text = string.format("%s ", ICONS.left_hard) })

  -- Workspace name
  local workspace = window:active_workspace()
  -- table.insert(left_status, { Background = { Color = colors.dark_bg } })
  -- table.insert(left_status, { Background = { Color = colors.other_bg:darken(0.2) } })
  -- table.insert(left_status, { Text = string.format("%s", ICONS.left_hard) })
  table.insert(left_status, { Background = { Color = colors.other_bg:darken(0.2) } })
  table.insert(left_status, { Foreground = { Color = colors.blue:saturate(0.5) } })
  table.insert(left_status, { Text = string.format("%s ", ICONS.workspace) })
  table.insert(left_status, { Foreground = { Color = colors.fg } })
  table.insert(left_status, { Text = string.format(" %s ", workspace) })

  window:set_left_status(wezterm.format(left_status))

  -- Right status
  local right_status = {}

  -- Time
  local time = wezterm.strftime("%m-%d %H:%M")
  table.insert(right_status, { Foreground = { Color = colors.fg:desaturate(0.1) } })
  table.insert(right_status, { Text = string.format("%s", ICONS.right_hard) })
  table.insert(right_status, { Background = { Color = colors.fg:desaturate(0.1) } })
  table.insert(right_status, { Attribute = { Intensity = "Bold" } })
  table.insert(right_status, { Foreground = { Color = colors.dark_bg } })
  table.insert(right_status, { Text = string.format(" %s ", time) })

  window:set_right_status(wezterm.format(right_status))
end)

function M.apply_to_config(config)
  config.tab_max_width = 32
  config.enable_tab_bar = true
  config.tab_bar_at_bottom = true
  config.use_fancy_tab_bar = false
  config.status_update_interval = 500
  config.show_tab_index_in_tab_bar = true
  config.hide_tab_bar_if_only_one_tab = false
  config.show_new_tab_button_in_tab_bar = false
  config.switch_to_last_active_tab_when_closing_tab = false

  config.colors.tab_bar = {
    background = wezterm.GLOBAL.scheme.background,
  }

end

return M
