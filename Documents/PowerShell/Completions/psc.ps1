# PSCompletions (psc) tab completion
Register-ArgumentCompleter -CommandName psc, PSCompletions -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)

    $tokens = $commandAst.ToString() -split '\s+'
    $count = $tokens.Count

    # If cursor is at a space after the last token, we're completing the next position
    $completingNext = $commandAst.ToString().Length -lt $cursorPosition -or
                      $commandAst.ToString()[$cursorPosition - 1] -eq ' '
    if ($completingNext) { $count++ }

    $subcommands = @{
        root = @(
            @{ Name = 'add';        Tip = 'Add completion(s)' }
            @{ Name = 'alias';      Tip = 'Manage completion trigger aliases' }
            @{ Name = 'completion'; Tip = 'Get/set per-completion configuration' }
            @{ Name = 'config';     Tip = 'Get/set module configuration' }
            @{ Name = 'info';       Tip = 'Get completion information' }
            @{ Name = 'list';       Tip = 'List installed completions' }
            @{ Name = 'menu';       Tip = 'Manage completion menu settings' }
            @{ Name = 'reset';      Tip = 'Reset configuration to defaults' }
            @{ Name = 'rm';         Tip = 'Remove completion(s)' }
            @{ Name = 'search';     Tip = 'Search available completions' }
            @{ Name = 'update';     Tip = 'Update completion(s)' }
            @{ Name = 'which';      Tip = 'Locate completion storage path' }
        )
        alias = @(
            @{ Name = 'add';  Tip = 'Add alias for a completion' }
            @{ Name = 'list'; Tip = 'List all completion aliases' }
            @{ Name = 'rm';   Tip = 'Remove alias from a completion' }
        )
        config = @(
            @{ Name = 'enable_auto_alias_setup';   Tip = 'Auto Set-Alias for psc aliases (0|1)' }
            @{ Name = 'enable_cache';              Tip = 'Enable completion cache (0|1)' }
            @{ Name = 'enable_completions_update'; Tip = 'Show update notifications (0|1)' }
            @{ Name = 'enable_module_update';      Tip = 'Show module update notifications (0|1)' }
            @{ Name = 'language';                  Tip = 'Set language (en-US|zh-CN)' }
            @{ Name = 'url';                       Tip = 'Set completion library URL' }
        )
        menu = @(
            @{ Name = 'color_theme'; Tip = 'Set menu color theme' }
            @{ Name = 'config';      Tip = 'Menu behavior configuration' }
            @{ Name = 'custom';      Tip = 'Customize menu style (color|line)' }
            @{ Name = 'line_theme';  Tip = 'Set menu border style theme' }
            @{ Name = 'symbol';      Tip = 'Set prediction symbols' }
        )
        menu_config = @(
            @{ Name = 'between_item_and_symbol';                    Tip = 'Separator between item and symbol' }
            @{ Name = 'completion_suffix';                          Tip = 'Suffix added after applying completion' }
            @{ Name = 'completions_confirm_limit';                  Tip = 'Confirm when items exceed limit (0=off)' }
            @{ Name = 'enable_completions_sort';                    Tip = 'Sort by command history (0|1)' }
            @{ Name = 'enable_enter_when_single';                   Tip = 'Auto-enter single item (0|1)' }
            @{ Name = 'enable_hooks_tip';                           Tip = 'Show tips for hook items (0|1)' }
            @{ Name = 'enable_list_follow_cursor';                  Tip = 'List follows cursor (0|1)' }
            @{ Name = 'enable_list_full_width';                     Tip = 'Full-width list (0|1)' }
            @{ Name = 'enable_list_loop';                           Tip = 'Loop list navigation (0|1)' }
            @{ Name = 'enable_menu';                                Tip = 'Use PSC module menu (0|1)' }
            @{ Name = 'enable_menu_enhance';                        Tip = 'Enhanced menu features (0|1)' }
            @{ Name = 'enable_menu_show_below';                     Tip = 'Force menu below cursor (0|1)' }
            @{ Name = 'enable_path_with_trailing_separator';        Tip = 'Path completion trailing separator (0|1)' }
            @{ Name = 'enable_tip';                                 Tip = 'Show completion tips (0|1)' }
            @{ Name = 'enable_tip_follow_cursor';                   Tip = 'Tip follows cursor (0|1)' }
            @{ Name = 'enable_tip_when_enhance';                    Tip = 'Show tips for non-psc completions (0|1)' }
            @{ Name = 'filter_symbol';                              Tip = 'Filter area symbols (default: [])' }
            @{ Name = 'height_from_menu_bottom_to_cursor_when_above'; Tip = 'Menu-to-cursor gap when above' }
            @{ Name = 'height_from_menu_top_to_cursor_when_below';    Tip = 'Menu-to-cursor gap when below' }
            @{ Name = 'list_max_count_when_above';                  Tip = 'Max items when menu above (0=auto)' }
            @{ Name = 'list_max_count_when_below';                  Tip = 'Max items when menu below (0=auto)' }
            @{ Name = 'list_min_width';                             Tip = 'Min list width (default: 10)' }
            @{ Name = 'status_symbol';                              Tip = 'Count status separator (default: /)' }
            @{ Name = 'trigger_key';                                Tip = 'Key that triggers menu (default: Tab)' }
        )
        menu_custom = @(
            @{ Name = 'color'; Tip = 'Customize menu colors' }
            @{ Name = 'line';  Tip = 'Customize menu border characters' }
        )
        menu_custom_color = @(
            @{ Name = 'border_color';   Tip = 'Border foreground color' }
            @{ Name = 'filter_color';   Tip = 'Filter box foreground color' }
            @{ Name = 'item_color';     Tip = 'Item foreground color' }
            @{ Name = 'selected_bgcolor'; Tip = 'Selected item background color' }
            @{ Name = 'selected_color'; Tip = 'Selected item foreground color' }
            @{ Name = 'status_color';   Tip = 'Status count foreground color' }
            @{ Name = 'tip_color';      Tip = 'Tip foreground color' }
        )
        menu_custom_line = @(
            @{ Name = 'bottom_left';  Tip = 'Bottom-left corner character' }
            @{ Name = 'bottom_right'; Tip = 'Bottom-right corner character' }
            @{ Name = 'horizontal';   Tip = 'Horizontal line character' }
            @{ Name = 'top_left';     Tip = 'Top-left corner character' }
            @{ Name = 'top_right';    Tip = 'Top-right corner character' }
            @{ Name = 'vertical';     Tip = 'Vertical line character' }
        )
        menu_symbol = @(
            @{ Name = 'OptionTab';     Tip = 'Option prediction symbol (default: ?)' }
            @{ Name = 'SpaceTab';      Tip = 'Space prediction symbol (default: ~)' }
            @{ Name = 'WriteSpaceTab'; Tip = 'Write prediction symbol (default: !)' }
        )
        reset = @(
            @{ Name = '*';          Tip = 'Reset entire module' }
            @{ Name = 'alias';      Tip = 'Reset aliases to defaults' }
            @{ Name = 'completion'; Tip = 'Reset per-completion configs' }
            @{ Name = 'config';     Tip = 'Reset module config' }
            @{ Name = 'menu';       Tip = 'Reset menu config' }
            @{ Name = 'order';      Tip = 'Reset sort order' }
        )
        list = @(
            @{ Name = '--remote'; Tip = 'Show all available completions from repo' }
        )
        update = @(
            @{ Name = '*';      Tip = 'Update all completions' }
            @{ Name = '--force'; Tip = 'Force update all added completions' }
        )
        color_theme = @(
            'Blue','Cyan','DarkBlue','DarkCyan','DarkGray','DarkGreen',
            'DarkMagenta','DarkRed','DarkYellow','Default','Gray',
            'Green','Magenta','Red','Yellow'
        ) | ForEach-Object { @{ Name = $_; Tip = 'Color theme' } }
        line_theme = @(
            @{ Name = 'bold_line_rect_border';       Tip = '┏━┓ Bold rectangular' }
            @{ Name = 'boldTB_slimLR_border';        Tip = '┍━┑ Bold top/bottom' }
            @{ Name = 'double_line_rect_border';     Tip = '╔═╗ Double line' }
            @{ Name = 'doubleTB_singleLR_border';    Tip = '╒═╕ Double top/bottom' }
            @{ Name = 'single_line_rect_border';     Tip = '┌─┐ Single rectangular' }
            @{ Name = 'single_line_round_border';    Tip = '╭─╮ Single rounded (default)' }
            @{ Name = 'singleTB_doubleLR_border';    Tip = '╓─╖ Single top/bottom' }
            @{ Name = 'slimTB_boldLR_border';        Tip = '┎─┒ Slim top/bottom' }
        )
    }

    # Resolve which completion set to use
    $completions = switch ($count) {
        2 { $subcommands.root }
        3 {
            switch ($tokens[1]) {
                'alias'  { $subcommands.alias }
                'config' { $subcommands.config }
                'menu'   { $subcommands.menu }
                'reset'  { $subcommands.reset }
                'list'   { $subcommands.list }
                'update' { $subcommands.update }
                { $_ -in 'add', 'rm', 'info', 'which', 'completion', 'search' } {
                    # Dynamic: suggest installed completions
                    if ($_ -eq 'add') {
                        try { $PSCompletions.list | ForEach-Object { @{ Name = $_; Tip = 'Available completion' } } } catch { @() }
                    } else {
                        try { $PSCompletions.data.list | ForEach-Object { @{ Name = $_; Tip = 'Installed completion' } } } catch { @() }
                    }
                }
                default { @() }
            }
        }
        4 {
            switch ($tokens[1]) {
                'menu' {
                    switch ($tokens[2]) {
                        'color_theme' { $subcommands.color_theme }
                        'config'      { $subcommands.menu_config }
                        'custom'      { $subcommands.menu_custom }
                        'line_theme'  { $subcommands.line_theme }
                        'symbol'      { $subcommands.menu_symbol }
                        default       { @() }
                    }
                }
                'alias' {
                    if ($tokens[2] -in 'add', 'rm') {
                        try { $PSCompletions.data.list | ForEach-Object { @{ Name = $_; Tip = 'Installed completion' } } } catch { @() }
                    } else { @() }
                }
                'config' {
                    switch ($tokens[2]) {
                        'language' { @(@{ Name = 'en-US'; Tip = 'English' }, @{ Name = 'zh-CN'; Tip = 'Chinese' }) }
                        { $_ -in 'enable_auto_alias_setup','enable_cache','enable_completions_update','enable_module_update' } {
                            @(@{ Name = '0'; Tip = 'Disabled' }, @{ Name = '1'; Tip = 'Enabled' })
                        }
                        default { @() }
                    }
                }
                default { @() }
            }
        }
        5 {
            if ($tokens[1] -eq 'menu' -and $tokens[2] -eq 'custom') {
                switch ($tokens[3]) {
                    'color' { $subcommands.menu_custom_color }
                    'line'  { $subcommands.menu_custom_line }
                    default { @() }
                }
            } else { @() }
        }
        default { @() }
    }

    $completions | Where-Object { $_.Name -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new(
            $_.Name, $_.Name, 'ParameterValue', $_.Tip
        )
    }
}
