
using namespace System.Management.Automation
using namespace System.Management.Automation.Language

Register-ArgumentCompleter -Native -CommandName 'ludusavi' -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)

    $commandElements = $commandAst.CommandElements
    $command = @(
        'ludusavi'
        for ($i = 1; $i -lt $commandElements.Count; $i++) {
            $element = $commandElements[$i]
            if ($element -isnot [StringConstantExpressionAst] -or
                $element.StringConstantType -ne [StringConstantType]::BareWord -or
                $element.Value.StartsWith('-') -or
                $element.Value -eq $wordToComplete) {
                break
        }
        $element.Value
    }) -join ';'

    $completions = @(switch ($command) {
        'ludusavi' {
            [CompletionResult]::new('--config', '--config', [CompletionResultType]::ParameterName, 'Use configuration found in a specific directory. It will be created if it does not exist')
            [CompletionResult]::new('--no-manifest-update', '--no-manifest-update', [CompletionResultType]::ParameterName, 'Disable automatic/implicit manifest update checks')
            [CompletionResult]::new('--try-manifest-update', '--try-manifest-update', [CompletionResultType]::ParameterName, 'Ignore any errors during automatic/implicit manifest update checks')
            [CompletionResult]::new('--debug', '--debug', [CompletionResultType]::ParameterName, 'Use max log level and open log folder after running. This will create a separate `ludusavi_debug.log` file, without any rotation or maximum size. Be mindful that the file size may increase rapidly during a full scan')
            [CompletionResult]::new('-h', '-h', [CompletionResultType]::ParameterName, 'Print help')
            [CompletionResult]::new('--help', '--help', [CompletionResultType]::ParameterName, 'Print help')
            [CompletionResult]::new('-V', '-V ', [CompletionResultType]::ParameterName, 'Print version')
            [CompletionResult]::new('--version', '--version', [CompletionResultType]::ParameterName, 'Print version')
            [CompletionResult]::new('backup', 'backup', [CompletionResultType]::ParameterValue, 'Back up data')
            [CompletionResult]::new('restore', 'restore', [CompletionResultType]::ParameterValue, 'Restore data')
            [CompletionResult]::new('complete', 'complete', [CompletionResultType]::ParameterValue, 'Generate shell completion scripts')
            [CompletionResult]::new('backups', 'backups', [CompletionResultType]::ParameterValue, 'Show backups')
            [CompletionResult]::new('find', 'find', [CompletionResultType]::ParameterValue, 'Find game titles')
            [CompletionResult]::new('manifest', 'manifest', [CompletionResultType]::ParameterValue, 'Options for Ludusavi''s data set')
            [CompletionResult]::new('config', 'config', [CompletionResultType]::ParameterValue, 'Options for Ludusavi''s configuration')
            [CompletionResult]::new('cloud', 'cloud', [CompletionResultType]::ParameterValue, 'Cloud sync')
            [CompletionResult]::new('wrap', 'wrap', [CompletionResultType]::ParameterValue, 'Wrap restore/backup around game execution')
            [CompletionResult]::new('api', 'api', [CompletionResultType]::ParameterValue, 'Execute bulk requests using JSON input')
            [CompletionResult]::new('schema', 'schema', [CompletionResultType]::ParameterValue, 'Display schemas that Ludusavi uses')
            [CompletionResult]::new('gui', 'gui', [CompletionResultType]::ParameterValue, 'Open the GUI')
            [CompletionResult]::new('help', 'help', [CompletionResultType]::ParameterValue, 'Print this message or the help of the given subcommand(s)')
            break
        }
        'ludusavi;backup' {
            [CompletionResult]::new('--path', '--path', [CompletionResultType]::ParameterName, 'Directory in which to store the backup. It will be created if it does not already exist. When not specified, this defers to the config file')
            [CompletionResult]::new('--wine-prefix', '--wine-prefix', [CompletionResultType]::ParameterName, 'Extra Wine/Proton prefix to check for saves. This should be a folder with an immediate child folder named "drive_c" (or another letter)')
            [CompletionResult]::new('--sort', '--sort', [CompletionResultType]::ParameterName, 'Sort the game list by different criteria. When not specified, this defers to the config file')
            [CompletionResult]::new('--format', '--format', [CompletionResultType]::ParameterName, 'Format in which to store new backups. When not specified, this defers to the config file')
            [CompletionResult]::new('--compression', '--compression', [CompletionResultType]::ParameterName, 'Compression method to use for new zip backups. When not specified, this defers to the config file')
            [CompletionResult]::new('--compression-level', '--compression-level', [CompletionResultType]::ParameterName, 'Compression level to use for new zip backups. When not specified, this defers to the config file. Valid ranges: 1 to 9 for deflate/bzip2, -7 to 22 for zstd')
            [CompletionResult]::new('--full-limit', '--full-limit', [CompletionResultType]::ParameterName, 'Maximum number of full backups to retain per game. Must be between 1 and 255 (inclusive). When not specified, this defers to the config file')
            [CompletionResult]::new('--differential-limit', '--differential-limit', [CompletionResultType]::ParameterName, 'Maximum number of differential backups to retain per full backup. Must be between 0 and 255 (inclusive). When not specified, this defers to the config file')
            [CompletionResult]::new('--preview', '--preview', [CompletionResultType]::ParameterName, 'List out what would be included, but don''t actually perform the operation')
            [CompletionResult]::new('--force', '--force', [CompletionResultType]::ParameterName, 'Don''t ask for confirmation')
            [CompletionResult]::new('--no-force-cloud-conflict', '--no-force-cloud-conflict', [CompletionResultType]::ParameterName, 'Even if the `--force` option has been specified, ask how to resolve any cloud conflict rather than ignoring it and continuing silently')
            [CompletionResult]::new('--api', '--api', [CompletionResultType]::ParameterName, 'Print information to stdout in machine-readable JSON. This replaces the default, human-readable output')
            [CompletionResult]::new('--gui', '--gui', [CompletionResultType]::ParameterName, 'Use GUI dialogs for prompts and some information')
            [CompletionResult]::new('--cloud-sync', '--cloud-sync', [CompletionResultType]::ParameterName, 'Upload any changes to the cloud when the backup is complete. If the local and cloud backups are not in sync to begin with, then nothing will be uploaded. This has no effect on previews. When not specified, this defers to the config file')
            [CompletionResult]::new('--no-cloud-sync', '--no-cloud-sync', [CompletionResultType]::ParameterName, 'Don''t perform any cloud checks or synchronization. When not specified, this defers to the config file')
            [CompletionResult]::new('--dump-registry', '--dump-registry', [CompletionResultType]::ParameterName, 'Include the serialized registry content in the output. Only includes the native Windows registry, not Wine')
            [CompletionResult]::new('--include-disabled', '--include-disabled', [CompletionResultType]::ParameterName, 'By default, disabled games are skipped unless you name them explicitly. You can use this option to include all disabled games')
            [CompletionResult]::new('--ask-downgrade', '--ask-downgrade', [CompletionResultType]::ParameterName, 'Ask what to do when a game''s backup is newer than the live data. Currently, this only considers file-based saves, not the Windows registry. This option ignores `--force`')
            [CompletionResult]::new('-h', '-h', [CompletionResultType]::ParameterName, 'Print help (see more with ''--help'')')
            [CompletionResult]::new('--help', '--help', [CompletionResultType]::ParameterName, 'Print help (see more with ''--help'')')
            break
        }
        'ludusavi;restore' {
            [CompletionResult]::new('--path', '--path', [CompletionResultType]::ParameterName, 'Directory containing a Ludusavi backup. When not specified, this defers to the config file')
            [CompletionResult]::new('--sort', '--sort', [CompletionResultType]::ParameterName, 'Sort the game list by different criteria. When not specified, this defers to Ludusavi''s config file')
            [CompletionResult]::new('--backup', '--backup', [CompletionResultType]::ParameterName, 'Restore a specific backup, using an ID returned by the `backups` command. This is only valid when restoring a single game')
            [CompletionResult]::new('--preview', '--preview', [CompletionResultType]::ParameterName, 'List out what would be included, but don''t actually perform the operation')
            [CompletionResult]::new('--force', '--force', [CompletionResultType]::ParameterName, 'Don''t ask for confirmation')
            [CompletionResult]::new('--no-force-cloud-conflict', '--no-force-cloud-conflict', [CompletionResultType]::ParameterName, 'Even if the `--force` option has been specified, ask how to resolve any cloud conflict rather than ignoring it and continuing silently')
            [CompletionResult]::new('--api', '--api', [CompletionResultType]::ParameterName, 'Print information to stdout in machine-readable JSON. This replaces the default, human-readable output')
            [CompletionResult]::new('--gui', '--gui', [CompletionResultType]::ParameterName, 'Use GUI dialogs for prompts and some information')
            [CompletionResult]::new('--cloud-sync', '--cloud-sync', [CompletionResultType]::ParameterName, 'Warn if the local and cloud backups are out of sync. The restore will still proceed regardless. This has no effect on previews. When not specified, this defers to the config file')
            [CompletionResult]::new('--no-cloud-sync', '--no-cloud-sync', [CompletionResultType]::ParameterName, 'Don''t perform any cloud checks or synchronization. When not specified, this defers to the config file')
            [CompletionResult]::new('--dump-registry', '--dump-registry', [CompletionResultType]::ParameterName, 'Include the serialized registry content in the output. Only includes the native Windows registry, not Wine')
            [CompletionResult]::new('--include-disabled', '--include-disabled', [CompletionResultType]::ParameterName, 'By default, disabled games are skipped unless you name them explicitly. You can use this option to include all disabled games')
            [CompletionResult]::new('--ask-downgrade', '--ask-downgrade', [CompletionResultType]::ParameterName, 'Ask what to do when a game''s backup is older than the live data. Currently, this only considers file-based saves, not the Windows registry. This option ignores `--force`')
            [CompletionResult]::new('-h', '-h', [CompletionResultType]::ParameterName, 'Print help (see more with ''--help'')')
            [CompletionResult]::new('--help', '--help', [CompletionResultType]::ParameterName, 'Print help (see more with ''--help'')')
            break
        }
        'ludusavi;complete' {
            [CompletionResult]::new('-h', '-h', [CompletionResultType]::ParameterName, 'Print help')
            [CompletionResult]::new('--help', '--help', [CompletionResultType]::ParameterName, 'Print help')
            [CompletionResult]::new('bash', 'bash', [CompletionResultType]::ParameterValue, 'Completions for Bash')
            [CompletionResult]::new('fish', 'fish', [CompletionResultType]::ParameterValue, 'Completions for Fish')
            [CompletionResult]::new('zsh', 'zsh', [CompletionResultType]::ParameterValue, 'Completions for Zsh')
            [CompletionResult]::new('powershell', 'powershell', [CompletionResultType]::ParameterValue, 'Completions for PowerShell')
            [CompletionResult]::new('elvish', 'elvish', [CompletionResultType]::ParameterValue, 'Completions for Elvish')
            [CompletionResult]::new('help', 'help', [CompletionResultType]::ParameterValue, 'Print this message or the help of the given subcommand(s)')
            break
        }
        'ludusavi;complete;bash' {
            [CompletionResult]::new('-h', '-h', [CompletionResultType]::ParameterName, 'Print help')
            [CompletionResult]::new('--help', '--help', [CompletionResultType]::ParameterName, 'Print help')
            break
        }
        'ludusavi;complete;fish' {
            [CompletionResult]::new('-h', '-h', [CompletionResultType]::ParameterName, 'Print help')
            [CompletionResult]::new('--help', '--help', [CompletionResultType]::ParameterName, 'Print help')
            break
        }
        'ludusavi;complete;zsh' {
            [CompletionResult]::new('-h', '-h', [CompletionResultType]::ParameterName, 'Print help')
            [CompletionResult]::new('--help', '--help', [CompletionResultType]::ParameterName, 'Print help')
            break
        }
        'ludusavi;complete;powershell' {
            [CompletionResult]::new('-h', '-h', [CompletionResultType]::ParameterName, 'Print help')
            [CompletionResult]::new('--help', '--help', [CompletionResultType]::ParameterName, 'Print help')
            break
        }
        'ludusavi;complete;elvish' {
            [CompletionResult]::new('-h', '-h', [CompletionResultType]::ParameterName, 'Print help')
            [CompletionResult]::new('--help', '--help', [CompletionResultType]::ParameterName, 'Print help')
            break
        }
        'ludusavi;complete;help' {
            [CompletionResult]::new('bash', 'bash', [CompletionResultType]::ParameterValue, 'Completions for Bash')
            [CompletionResult]::new('fish', 'fish', [CompletionResultType]::ParameterValue, 'Completions for Fish')
            [CompletionResult]::new('zsh', 'zsh', [CompletionResultType]::ParameterValue, 'Completions for Zsh')
            [CompletionResult]::new('powershell', 'powershell', [CompletionResultType]::ParameterValue, 'Completions for PowerShell')
            [CompletionResult]::new('elvish', 'elvish', [CompletionResultType]::ParameterValue, 'Completions for Elvish')
            [CompletionResult]::new('help', 'help', [CompletionResultType]::ParameterValue, 'Print this message or the help of the given subcommand(s)')
            break
        }
        'ludusavi;complete;help;bash' {
            break
        }
        'ludusavi;complete;help;fish' {
            break
        }
        'ludusavi;complete;help;zsh' {
            break
        }
        'ludusavi;complete;help;powershell' {
            break
        }
        'ludusavi;complete;help;elvish' {
            break
        }
        'ludusavi;complete;help;help' {
            break
        }
        'ludusavi;backups' {
            [CompletionResult]::new('--path', '--path', [CompletionResultType]::ParameterName, 'Directory in which to find backups. When unset, this defaults to the restore path from the config file')
            [CompletionResult]::new('--api', '--api', [CompletionResultType]::ParameterName, 'Print information to stdout in machine-readable JSON. This replaces the default, human-readable output')
            [CompletionResult]::new('-h', '-h', [CompletionResultType]::ParameterName, 'Print help')
            [CompletionResult]::new('--help', '--help', [CompletionResultType]::ParameterName, 'Print help')
            [CompletionResult]::new('edit', 'edit', [CompletionResultType]::ParameterValue, 'Edit a backup')
            [CompletionResult]::new('help', 'help', [CompletionResultType]::ParameterValue, 'Print this message or the help of the given subcommand(s)')
            break
        }
        'ludusavi;backups;edit' {
            [CompletionResult]::new('--path', '--path', [CompletionResultType]::ParameterName, 'Directory in which to find backups. When unset, this defaults to the restore path from the config file')
            [CompletionResult]::new('--backup', '--backup', [CompletionResultType]::ParameterName, 'Edit a specific backup, using an ID returned by the `backups` command. When not specified, this defaults to the latest backup')
            [CompletionResult]::new('--comment', '--comment', [CompletionResultType]::ParameterName, 'comment')
            [CompletionResult]::new('--lock', '--lock', [CompletionResultType]::ParameterName, 'lock')
            [CompletionResult]::new('--unlock', '--unlock', [CompletionResultType]::ParameterName, 'unlock')
            [CompletionResult]::new('-h', '-h', [CompletionResultType]::ParameterName, 'Print help (see more with ''--help'')')
            [CompletionResult]::new('--help', '--help', [CompletionResultType]::ParameterName, 'Print help (see more with ''--help'')')
            break
        }
        'ludusavi;backups;help' {
            [CompletionResult]::new('edit', 'edit', [CompletionResultType]::ParameterValue, 'Edit a backup')
            [CompletionResult]::new('help', 'help', [CompletionResultType]::ParameterValue, 'Print this message or the help of the given subcommand(s)')
            break
        }
        'ludusavi;backups;help;edit' {
            break
        }
        'ludusavi;backups;help;help' {
            break
        }
        'ludusavi;find' {
            [CompletionResult]::new('--path', '--path', [CompletionResultType]::ParameterName, 'Directory in which to find backups. When unset, this defaults to the restore path from the config file')
            [CompletionResult]::new('--steam-id', '--steam-id', [CompletionResultType]::ParameterName, 'Look up game by a Steam ID')
            [CompletionResult]::new('--gog-id', '--gog-id', [CompletionResultType]::ParameterName, 'Look up game by a GOG ID')
            [CompletionResult]::new('--lutris-id', '--lutris-id', [CompletionResultType]::ParameterName, 'Look up game by a Lutris slug')
            [CompletionResult]::new('--api', '--api', [CompletionResultType]::ParameterName, 'Print information to stdout in machine-readable JSON. This replaces the default, human-readable output')
            [CompletionResult]::new('--multiple', '--multiple', [CompletionResultType]::ParameterName, 'Keep looking for all potential matches, instead of stopping at the first match')
            [CompletionResult]::new('--backup', '--backup', [CompletionResultType]::ParameterName, 'Ensure the game is recognized in a backup context')
            [CompletionResult]::new('--restore', '--restore', [CompletionResultType]::ParameterName, 'Ensure the game is recognized in a restore context')
            [CompletionResult]::new('--normalized', '--normalized', [CompletionResultType]::ParameterName, 'Look up game by an approximation of the title. Ignores capitalization, "edition" suffixes, year suffixes, and some special symbols. This may find multiple games for a single input')
            [CompletionResult]::new('--fuzzy', '--fuzzy', [CompletionResultType]::ParameterName, 'Look up games with fuzzy matching. This may find multiple games for a single input')
            [CompletionResult]::new('--disabled', '--disabled', [CompletionResultType]::ParameterName, 'Select games that are disabled')
            [CompletionResult]::new('--partial', '--partial', [CompletionResultType]::ParameterName, 'Select games that have some saves disabled')
            [CompletionResult]::new('-h', '-h', [CompletionResultType]::ParameterName, 'Print help (see more with ''--help'')')
            [CompletionResult]::new('--help', '--help', [CompletionResultType]::ParameterName, 'Print help (see more with ''--help'')')
            break
        }
        'ludusavi;manifest' {
            [CompletionResult]::new('-h', '-h', [CompletionResultType]::ParameterName, 'Print help')
            [CompletionResult]::new('--help', '--help', [CompletionResultType]::ParameterName, 'Print help')
            [CompletionResult]::new('show', 'show', [CompletionResultType]::ParameterValue, 'Print the content of the manifest, including any custom entries')
            [CompletionResult]::new('update', 'update', [CompletionResultType]::ParameterValue, 'Check for any manifest updates and download if available. By default, does nothing if the most recent check was within the last 24 hours')
            [CompletionResult]::new('help', 'help', [CompletionResultType]::ParameterValue, 'Print this message or the help of the given subcommand(s)')
            break
        }
        'ludusavi;manifest;show' {
            [CompletionResult]::new('--api', '--api', [CompletionResultType]::ParameterName, 'Print information to stdout in machine-readable JSON')
            [CompletionResult]::new('-h', '-h', [CompletionResultType]::ParameterName, 'Print help')
            [CompletionResult]::new('--help', '--help', [CompletionResultType]::ParameterName, 'Print help')
            break
        }
        'ludusavi;manifest;update' {
            [CompletionResult]::new('--force', '--force', [CompletionResultType]::ParameterName, 'Check again even if the most recent check was within the last 24 hours')
            [CompletionResult]::new('-h', '-h', [CompletionResultType]::ParameterName, 'Print help')
            [CompletionResult]::new('--help', '--help', [CompletionResultType]::ParameterName, 'Print help')
            break
        }
        'ludusavi;manifest;help' {
            [CompletionResult]::new('show', 'show', [CompletionResultType]::ParameterValue, 'Print the content of the manifest, including any custom entries')
            [CompletionResult]::new('update', 'update', [CompletionResultType]::ParameterValue, 'Check for any manifest updates and download if available. By default, does nothing if the most recent check was within the last 24 hours')
            [CompletionResult]::new('help', 'help', [CompletionResultType]::ParameterValue, 'Print this message or the help of the given subcommand(s)')
            break
        }
        'ludusavi;manifest;help;show' {
            break
        }
        'ludusavi;manifest;help;update' {
            break
        }
        'ludusavi;manifest;help;help' {
            break
        }
        'ludusavi;config' {
            [CompletionResult]::new('-h', '-h', [CompletionResultType]::ParameterName, 'Print help')
            [CompletionResult]::new('--help', '--help', [CompletionResultType]::ParameterName, 'Print help')
            [CompletionResult]::new('path', 'path', [CompletionResultType]::ParameterValue, 'Print the path to the config file')
            [CompletionResult]::new('show', 'show', [CompletionResultType]::ParameterValue, 'Print the active configuration')
            [CompletionResult]::new('help', 'help', [CompletionResultType]::ParameterValue, 'Print this message or the help of the given subcommand(s)')
            break
        }
        'ludusavi;config;path' {
            [CompletionResult]::new('-h', '-h', [CompletionResultType]::ParameterName, 'Print help')
            [CompletionResult]::new('--help', '--help', [CompletionResultType]::ParameterName, 'Print help')
            break
        }
        'ludusavi;config;show' {
            [CompletionResult]::new('--api', '--api', [CompletionResultType]::ParameterName, 'Print information to stdout in machine-readable JSON')
            [CompletionResult]::new('--default', '--default', [CompletionResultType]::ParameterName, 'Print the default configuration')
            [CompletionResult]::new('-h', '-h', [CompletionResultType]::ParameterName, 'Print help')
            [CompletionResult]::new('--help', '--help', [CompletionResultType]::ParameterName, 'Print help')
            break
        }
        'ludusavi;config;help' {
            [CompletionResult]::new('path', 'path', [CompletionResultType]::ParameterValue, 'Print the path to the config file')
            [CompletionResult]::new('show', 'show', [CompletionResultType]::ParameterValue, 'Print the active configuration')
            [CompletionResult]::new('help', 'help', [CompletionResultType]::ParameterValue, 'Print this message or the help of the given subcommand(s)')
            break
        }
        'ludusavi;config;help;path' {
            break
        }
        'ludusavi;config;help;show' {
            break
        }
        'ludusavi;config;help;help' {
            break
        }
        'ludusavi;cloud' {
            [CompletionResult]::new('-h', '-h', [CompletionResultType]::ParameterName, 'Print help')
            [CompletionResult]::new('--help', '--help', [CompletionResultType]::ParameterName, 'Print help')
            [CompletionResult]::new('set', 'set', [CompletionResultType]::ParameterValue, 'Configure the cloud system to use')
            [CompletionResult]::new('upload', 'upload', [CompletionResultType]::ParameterValue, 'Upload your local backups to the cloud, overwriting any existing cloud backups')
            [CompletionResult]::new('download', 'download', [CompletionResultType]::ParameterValue, 'Download your cloud backups, overwriting any existing local backups')
            [CompletionResult]::new('help', 'help', [CompletionResultType]::ParameterValue, 'Print this message or the help of the given subcommand(s)')
            break
        }
        'ludusavi;cloud;set' {
            [CompletionResult]::new('-h', '-h', [CompletionResultType]::ParameterName, 'Print help')
            [CompletionResult]::new('--help', '--help', [CompletionResultType]::ParameterName, 'Print help')
            [CompletionResult]::new('none', 'none', [CompletionResultType]::ParameterValue, 'Disable cloud backups')
            [CompletionResult]::new('custom', 'custom', [CompletionResultType]::ParameterValue, 'Use a pre-existing Rclone remote')
            [CompletionResult]::new('box', 'box', [CompletionResultType]::ParameterValue, 'Use Box')
            [CompletionResult]::new('dropbox', 'dropbox', [CompletionResultType]::ParameterValue, 'Use Dropbox')
            [CompletionResult]::new('google-drive', 'google-drive', [CompletionResultType]::ParameterValue, 'Use Google Drive')
            [CompletionResult]::new('onedrive', 'onedrive', [CompletionResultType]::ParameterValue, 'Use OneDrive')
            [CompletionResult]::new('ftp', 'ftp', [CompletionResultType]::ParameterValue, 'Use an FTP server')
            [CompletionResult]::new('smb', 'smb', [CompletionResultType]::ParameterValue, 'Use an SMB server')
            [CompletionResult]::new('webdav', 'webdav', [CompletionResultType]::ParameterValue, 'Use a WebDAV server')
            [CompletionResult]::new('help', 'help', [CompletionResultType]::ParameterValue, 'Print this message or the help of the given subcommand(s)')
            break
        }
        'ludusavi;cloud;set;none' {
            [CompletionResult]::new('-h', '-h', [CompletionResultType]::ParameterName, 'Print help')
            [CompletionResult]::new('--help', '--help', [CompletionResultType]::ParameterName, 'Print help')
            break
        }
        'ludusavi;cloud;set;custom' {
            [CompletionResult]::new('--id', '--id', [CompletionResultType]::ParameterName, 'id')
            [CompletionResult]::new('-h', '-h', [CompletionResultType]::ParameterName, 'Print help')
            [CompletionResult]::new('--help', '--help', [CompletionResultType]::ParameterName, 'Print help')
            break
        }
        'ludusavi;cloud;set;box' {
            [CompletionResult]::new('-h', '-h', [CompletionResultType]::ParameterName, 'Print help')
            [CompletionResult]::new('--help', '--help', [CompletionResultType]::ParameterName, 'Print help')
            break
        }
        'ludusavi;cloud;set;dropbox' {
            [CompletionResult]::new('-h', '-h', [CompletionResultType]::ParameterName, 'Print help')
            [CompletionResult]::new('--help', '--help', [CompletionResultType]::ParameterName, 'Print help')
            break
        }
        'ludusavi;cloud;set;google-drive' {
            [CompletionResult]::new('-h', '-h', [CompletionResultType]::ParameterName, 'Print help')
            [CompletionResult]::new('--help', '--help', [CompletionResultType]::ParameterName, 'Print help')
            break
        }
        'ludusavi;cloud;set;onedrive' {
            [CompletionResult]::new('-h', '-h', [CompletionResultType]::ParameterName, 'Print help')
            [CompletionResult]::new('--help', '--help', [CompletionResultType]::ParameterName, 'Print help')
            break
        }
        'ludusavi;cloud;set;ftp' {
            [CompletionResult]::new('--host', '--host', [CompletionResultType]::ParameterName, 'Host URL')
            [CompletionResult]::new('--port', '--port', [CompletionResultType]::ParameterName, 'Port number')
            [CompletionResult]::new('--username', '--username', [CompletionResultType]::ParameterName, 'Username for authentication')
            [CompletionResult]::new('--password', '--password', [CompletionResultType]::ParameterName, 'Password for authentication')
            [CompletionResult]::new('-h', '-h', [CompletionResultType]::ParameterName, 'Print help')
            [CompletionResult]::new('--help', '--help', [CompletionResultType]::ParameterName, 'Print help')
            break
        }
        'ludusavi;cloud;set;smb' {
            [CompletionResult]::new('--host', '--host', [CompletionResultType]::ParameterName, 'Host URL')
            [CompletionResult]::new('--port', '--port', [CompletionResultType]::ParameterName, 'Port number')
            [CompletionResult]::new('--username', '--username', [CompletionResultType]::ParameterName, 'Username for authentication')
            [CompletionResult]::new('--password', '--password', [CompletionResultType]::ParameterName, 'Password for authentication')
            [CompletionResult]::new('-h', '-h', [CompletionResultType]::ParameterName, 'Print help')
            [CompletionResult]::new('--help', '--help', [CompletionResultType]::ParameterName, 'Print help')
            break
        }
        'ludusavi;cloud;set;webdav' {
            [CompletionResult]::new('--url', '--url', [CompletionResultType]::ParameterName, 'URL')
            [CompletionResult]::new('--username', '--username', [CompletionResultType]::ParameterName, 'Username for authentication')
            [CompletionResult]::new('--password', '--password', [CompletionResultType]::ParameterName, 'Password for authentication')
            [CompletionResult]::new('--provider', '--provider', [CompletionResultType]::ParameterName, 'Service provider')
            [CompletionResult]::new('-h', '-h', [CompletionResultType]::ParameterName, 'Print help')
            [CompletionResult]::new('--help', '--help', [CompletionResultType]::ParameterName, 'Print help')
            break
        }
        'ludusavi;cloud;set;help' {
            [CompletionResult]::new('none', 'none', [CompletionResultType]::ParameterValue, 'Disable cloud backups')
            [CompletionResult]::new('custom', 'custom', [CompletionResultType]::ParameterValue, 'Use a pre-existing Rclone remote')
            [CompletionResult]::new('box', 'box', [CompletionResultType]::ParameterValue, 'Use Box')
            [CompletionResult]::new('dropbox', 'dropbox', [CompletionResultType]::ParameterValue, 'Use Dropbox')
            [CompletionResult]::new('google-drive', 'google-drive', [CompletionResultType]::ParameterValue, 'Use Google Drive')
            [CompletionResult]::new('onedrive', 'onedrive', [CompletionResultType]::ParameterValue, 'Use OneDrive')
            [CompletionResult]::new('ftp', 'ftp', [CompletionResultType]::ParameterValue, 'Use an FTP server')
            [CompletionResult]::new('smb', 'smb', [CompletionResultType]::ParameterValue, 'Use an SMB server')
            [CompletionResult]::new('webdav', 'webdav', [CompletionResultType]::ParameterValue, 'Use a WebDAV server')
            [CompletionResult]::new('help', 'help', [CompletionResultType]::ParameterValue, 'Print this message or the help of the given subcommand(s)')
            break
        }
        'ludusavi;cloud;set;help;none' {
            break
        }
        'ludusavi;cloud;set;help;custom' {
            break
        }
        'ludusavi;cloud;set;help;box' {
            break
        }
        'ludusavi;cloud;set;help;dropbox' {
            break
        }
        'ludusavi;cloud;set;help;google-drive' {
            break
        }
        'ludusavi;cloud;set;help;onedrive' {
            break
        }
        'ludusavi;cloud;set;help;ftp' {
            break
        }
        'ludusavi;cloud;set;help;smb' {
            break
        }
        'ludusavi;cloud;set;help;webdav' {
            break
        }
        'ludusavi;cloud;set;help;help' {
            break
        }
        'ludusavi;cloud;upload' {
            [CompletionResult]::new('--local', '--local', [CompletionResultType]::ParameterName, 'Local folder path for backups. When not specified, this defers to the backup path from the config file')
            [CompletionResult]::new('--cloud', '--cloud', [CompletionResultType]::ParameterName, 'Cloud folder path for backups. When not specified, this defers to the config file')
            [CompletionResult]::new('--force', '--force', [CompletionResultType]::ParameterName, 'Don''t ask for confirmation')
            [CompletionResult]::new('--preview', '--preview', [CompletionResultType]::ParameterName, 'Check what would change, but don''t actually apply the changes')
            [CompletionResult]::new('--api', '--api', [CompletionResultType]::ParameterName, 'Print information to stdout in machine-readable JSON. This replaces the default, human-readable output')
            [CompletionResult]::new('--gui', '--gui', [CompletionResultType]::ParameterName, 'Use GUI dialogs for prompts and some information')
            [CompletionResult]::new('-h', '-h', [CompletionResultType]::ParameterName, 'Print help')
            [CompletionResult]::new('--help', '--help', [CompletionResultType]::ParameterName, 'Print help')
            break
        }
        'ludusavi;cloud;download' {
            [CompletionResult]::new('--local', '--local', [CompletionResultType]::ParameterName, 'Local folder path for backups. When not specified, this defers to the backup path from the config file')
            [CompletionResult]::new('--cloud', '--cloud', [CompletionResultType]::ParameterName, 'Cloud folder path for backups. When not specified, this defers to the config file')
            [CompletionResult]::new('--force', '--force', [CompletionResultType]::ParameterName, 'Don''t ask for confirmation')
            [CompletionResult]::new('--preview', '--preview', [CompletionResultType]::ParameterName, 'Check what would change, but don''t actually apply the changes')
            [CompletionResult]::new('--api', '--api', [CompletionResultType]::ParameterName, 'Print information to stdout in machine-readable JSON. This replaces the default, human-readable output')
            [CompletionResult]::new('--gui', '--gui', [CompletionResultType]::ParameterName, 'Use GUI dialogs for prompts and some information')
            [CompletionResult]::new('-h', '-h', [CompletionResultType]::ParameterName, 'Print help')
            [CompletionResult]::new('--help', '--help', [CompletionResultType]::ParameterName, 'Print help')
            break
        }
        'ludusavi;cloud;help' {
            [CompletionResult]::new('set', 'set', [CompletionResultType]::ParameterValue, 'Configure the cloud system to use')
            [CompletionResult]::new('upload', 'upload', [CompletionResultType]::ParameterValue, 'Upload your local backups to the cloud, overwriting any existing cloud backups')
            [CompletionResult]::new('download', 'download', [CompletionResultType]::ParameterValue, 'Download your cloud backups, overwriting any existing local backups')
            [CompletionResult]::new('help', 'help', [CompletionResultType]::ParameterValue, 'Print this message or the help of the given subcommand(s)')
            break
        }
        'ludusavi;cloud;help;set' {
            [CompletionResult]::new('none', 'none', [CompletionResultType]::ParameterValue, 'Disable cloud backups')
            [CompletionResult]::new('custom', 'custom', [CompletionResultType]::ParameterValue, 'Use a pre-existing Rclone remote')
            [CompletionResult]::new('box', 'box', [CompletionResultType]::ParameterValue, 'Use Box')
            [CompletionResult]::new('dropbox', 'dropbox', [CompletionResultType]::ParameterValue, 'Use Dropbox')
            [CompletionResult]::new('google-drive', 'google-drive', [CompletionResultType]::ParameterValue, 'Use Google Drive')
            [CompletionResult]::new('onedrive', 'onedrive', [CompletionResultType]::ParameterValue, 'Use OneDrive')
            [CompletionResult]::new('ftp', 'ftp', [CompletionResultType]::ParameterValue, 'Use an FTP server')
            [CompletionResult]::new('smb', 'smb', [CompletionResultType]::ParameterValue, 'Use an SMB server')
            [CompletionResult]::new('webdav', 'webdav', [CompletionResultType]::ParameterValue, 'Use a WebDAV server')
            break
        }
        'ludusavi;cloud;help;set;none' {
            break
        }
        'ludusavi;cloud;help;set;custom' {
            break
        }
        'ludusavi;cloud;help;set;box' {
            break
        }
        'ludusavi;cloud;help;set;dropbox' {
            break
        }
        'ludusavi;cloud;help;set;google-drive' {
            break
        }
        'ludusavi;cloud;help;set;onedrive' {
            break
        }
        'ludusavi;cloud;help;set;ftp' {
            break
        }
        'ludusavi;cloud;help;set;smb' {
            break
        }
        'ludusavi;cloud;help;set;webdav' {
            break
        }
        'ludusavi;cloud;help;upload' {
            break
        }
        'ludusavi;cloud;help;download' {
            break
        }
        'ludusavi;cloud;help;help' {
            break
        }
        'ludusavi;wrap' {
            [CompletionResult]::new('--infer', '--infer', [CompletionResultType]::ParameterName, 'Infer game name from commands based on launcher type')
            [CompletionResult]::new('--name', '--name', [CompletionResultType]::ParameterName, 'Directly set game name as known to Ludusavi')
            [CompletionResult]::new('--path', '--path', [CompletionResultType]::ParameterName, 'Directory in which to find/store backups. It will be created if it does not already exist. When not specified, this defers to the config file')
            [CompletionResult]::new('--format', '--format', [CompletionResultType]::ParameterName, 'Format in which to store new backups. When not specified, this defers to the config file')
            [CompletionResult]::new('--compression', '--compression', [CompletionResultType]::ParameterName, 'Compression method to use for new zip backups. When not specified, this defers to the config file')
            [CompletionResult]::new('--compression-level', '--compression-level', [CompletionResultType]::ParameterName, 'Compression level to use for new zip backups. When not specified, this defers to the config file. Valid ranges: 1 to 9 for deflate/bzip2, -7 to 22 for zstd')
            [CompletionResult]::new('--full-limit', '--full-limit', [CompletionResultType]::ParameterName, 'Maximum number of full backups to retain per game. Must be between 1 and 255 (inclusive). When not specified, this defers to the config file')
            [CompletionResult]::new('--differential-limit', '--differential-limit', [CompletionResultType]::ParameterName, 'Maximum number of differential backups to retain per full backup. Must be between 0 and 255 (inclusive). When not specified, this defers to the config file')
            [CompletionResult]::new('--force', '--force', [CompletionResultType]::ParameterName, 'Don''t ask for any confirmation')
            [CompletionResult]::new('--force-backup', '--force-backup', [CompletionResultType]::ParameterName, 'Don''t ask for confirmation when backing up')
            [CompletionResult]::new('--force-restore', '--force-restore', [CompletionResultType]::ParameterName, 'Don''t ask for confirmation when restoring')
            [CompletionResult]::new('--no-force-cloud-conflict', '--no-force-cloud-conflict', [CompletionResultType]::ParameterName, 'Even if another `--force` option has been specified, ask how to resolve any cloud conflict rather than ignoring it and continuing silently')
            [CompletionResult]::new('--gui', '--gui', [CompletionResultType]::ParameterName, 'Show a GUI notification during restore/backup')
            [CompletionResult]::new('--cloud-sync', '--cloud-sync', [CompletionResultType]::ParameterName, 'Upload any changes to the cloud when the backup is complete. If the local and cloud backups are not in sync to begin with, then nothing will be uploaded. When not specified, this defers to the config file')
            [CompletionResult]::new('--no-cloud-sync', '--no-cloud-sync', [CompletionResultType]::ParameterName, 'Don''t perform any cloud checks or synchronization. When not specified, this defers to the config file')
            [CompletionResult]::new('--ask-downgrade', '--ask-downgrade', [CompletionResultType]::ParameterName, 'When restoring, ask what to do when a game''s backup is older than the live data. When backing up, ask what to do when a game''s backup is newer than the live data. Currently, this only considers file-based saves, not the Windows registry. This option ignores `--force`')
            [CompletionResult]::new('-h', '-h', [CompletionResultType]::ParameterName, 'Print help')
            [CompletionResult]::new('--help', '--help', [CompletionResultType]::ParameterName, 'Print help')
            break
        }
        'ludusavi;api' {
            [CompletionResult]::new('-h', '-h', [CompletionResultType]::ParameterName, 'Print help (see more with ''--help'')')
            [CompletionResult]::new('--help', '--help', [CompletionResultType]::ParameterName, 'Print help (see more with ''--help'')')
            break
        }
        'ludusavi;schema' {
            [CompletionResult]::new('--format', '--format', [CompletionResultType]::ParameterName, 'format')
            [CompletionResult]::new('-h', '-h', [CompletionResultType]::ParameterName, 'Print help')
            [CompletionResult]::new('--help', '--help', [CompletionResultType]::ParameterName, 'Print help')
            [CompletionResult]::new('api-input', 'api-input', [CompletionResultType]::ParameterValue, 'Schema for `api` command input')
            [CompletionResult]::new('api-output', 'api-output', [CompletionResultType]::ParameterValue, 'Schema for `api` command output')
            [CompletionResult]::new('config', 'config', [CompletionResultType]::ParameterValue, 'Schema for config.yaml')
            [CompletionResult]::new('general-output', 'general-output', [CompletionResultType]::ParameterValue, 'Schema for general command output in --api mode (`backup`, `restore`, `backups`, `find`, `cloud upload`, `cloud download`)')
            [CompletionResult]::new('help', 'help', [CompletionResultType]::ParameterValue, 'Print this message or the help of the given subcommand(s)')
            break
        }
        'ludusavi;schema;api-input' {
            [CompletionResult]::new('-h', '-h', [CompletionResultType]::ParameterName, 'Print help')
            [CompletionResult]::new('--help', '--help', [CompletionResultType]::ParameterName, 'Print help')
            break
        }
        'ludusavi;schema;api-output' {
            [CompletionResult]::new('-h', '-h', [CompletionResultType]::ParameterName, 'Print help')
            [CompletionResult]::new('--help', '--help', [CompletionResultType]::ParameterName, 'Print help')
            break
        }
        'ludusavi;schema;config' {
            [CompletionResult]::new('-h', '-h', [CompletionResultType]::ParameterName, 'Print help')
            [CompletionResult]::new('--help', '--help', [CompletionResultType]::ParameterName, 'Print help')
            break
        }
        'ludusavi;schema;general-output' {
            [CompletionResult]::new('-h', '-h', [CompletionResultType]::ParameterName, 'Print help')
            [CompletionResult]::new('--help', '--help', [CompletionResultType]::ParameterName, 'Print help')
            break
        }
        'ludusavi;schema;help' {
            [CompletionResult]::new('api-input', 'api-input', [CompletionResultType]::ParameterValue, 'Schema for `api` command input')
            [CompletionResult]::new('api-output', 'api-output', [CompletionResultType]::ParameterValue, 'Schema for `api` command output')
            [CompletionResult]::new('config', 'config', [CompletionResultType]::ParameterValue, 'Schema for config.yaml')
            [CompletionResult]::new('general-output', 'general-output', [CompletionResultType]::ParameterValue, 'Schema for general command output in --api mode (`backup`, `restore`, `backups`, `find`, `cloud upload`, `cloud download`)')
            [CompletionResult]::new('help', 'help', [CompletionResultType]::ParameterValue, 'Print this message or the help of the given subcommand(s)')
            break
        }
        'ludusavi;schema;help;api-input' {
            break
        }
        'ludusavi;schema;help;api-output' {
            break
        }
        'ludusavi;schema;help;config' {
            break
        }
        'ludusavi;schema;help;general-output' {
            break
        }
        'ludusavi;schema;help;help' {
            break
        }
        'ludusavi;gui' {
            [CompletionResult]::new('--custom-game', '--custom-game', [CompletionResultType]::ParameterName, 'Open the custom game screen, then either create a new entry with this name or scroll to an existing entry')
            [CompletionResult]::new('-h', '-h', [CompletionResultType]::ParameterName, 'Print help')
            [CompletionResult]::new('--help', '--help', [CompletionResultType]::ParameterName, 'Print help')
            break
        }
        'ludusavi;help' {
            [CompletionResult]::new('backup', 'backup', [CompletionResultType]::ParameterValue, 'Back up data')
            [CompletionResult]::new('restore', 'restore', [CompletionResultType]::ParameterValue, 'Restore data')
            [CompletionResult]::new('complete', 'complete', [CompletionResultType]::ParameterValue, 'Generate shell completion scripts')
            [CompletionResult]::new('backups', 'backups', [CompletionResultType]::ParameterValue, 'Show backups')
            [CompletionResult]::new('find', 'find', [CompletionResultType]::ParameterValue, 'Find game titles')
            [CompletionResult]::new('manifest', 'manifest', [CompletionResultType]::ParameterValue, 'Options for Ludusavi''s data set')
            [CompletionResult]::new('config', 'config', [CompletionResultType]::ParameterValue, 'Options for Ludusavi''s configuration')
            [CompletionResult]::new('cloud', 'cloud', [CompletionResultType]::ParameterValue, 'Cloud sync')
            [CompletionResult]::new('wrap', 'wrap', [CompletionResultType]::ParameterValue, 'Wrap restore/backup around game execution')
            [CompletionResult]::new('api', 'api', [CompletionResultType]::ParameterValue, 'Execute bulk requests using JSON input')
            [CompletionResult]::new('schema', 'schema', [CompletionResultType]::ParameterValue, 'Display schemas that Ludusavi uses')
            [CompletionResult]::new('gui', 'gui', [CompletionResultType]::ParameterValue, 'Open the GUI')
            [CompletionResult]::new('help', 'help', [CompletionResultType]::ParameterValue, 'Print this message or the help of the given subcommand(s)')
            break
        }
        'ludusavi;help;backup' {
            break
        }
        'ludusavi;help;restore' {
            break
        }
        'ludusavi;help;complete' {
            [CompletionResult]::new('bash', 'bash', [CompletionResultType]::ParameterValue, 'Completions for Bash')
            [CompletionResult]::new('fish', 'fish', [CompletionResultType]::ParameterValue, 'Completions for Fish')
            [CompletionResult]::new('zsh', 'zsh', [CompletionResultType]::ParameterValue, 'Completions for Zsh')
            [CompletionResult]::new('powershell', 'powershell', [CompletionResultType]::ParameterValue, 'Completions for PowerShell')
            [CompletionResult]::new('elvish', 'elvish', [CompletionResultType]::ParameterValue, 'Completions for Elvish')
            break
        }
        'ludusavi;help;complete;bash' {
            break
        }
        'ludusavi;help;complete;fish' {
            break
        }
        'ludusavi;help;complete;zsh' {
            break
        }
        'ludusavi;help;complete;powershell' {
            break
        }
        'ludusavi;help;complete;elvish' {
            break
        }
        'ludusavi;help;backups' {
            [CompletionResult]::new('edit', 'edit', [CompletionResultType]::ParameterValue, 'Edit a backup')
            break
        }
        'ludusavi;help;backups;edit' {
            break
        }
        'ludusavi;help;find' {
            break
        }
        'ludusavi;help;manifest' {
            [CompletionResult]::new('show', 'show', [CompletionResultType]::ParameterValue, 'Print the content of the manifest, including any custom entries')
            [CompletionResult]::new('update', 'update', [CompletionResultType]::ParameterValue, 'Check for any manifest updates and download if available. By default, does nothing if the most recent check was within the last 24 hours')
            break
        }
        'ludusavi;help;manifest;show' {
            break
        }
        'ludusavi;help;manifest;update' {
            break
        }
        'ludusavi;help;config' {
            [CompletionResult]::new('path', 'path', [CompletionResultType]::ParameterValue, 'Print the path to the config file')
            [CompletionResult]::new('show', 'show', [CompletionResultType]::ParameterValue, 'Print the active configuration')
            break
        }
        'ludusavi;help;config;path' {
            break
        }
        'ludusavi;help;config;show' {
            break
        }
        'ludusavi;help;cloud' {
            [CompletionResult]::new('set', 'set', [CompletionResultType]::ParameterValue, 'Configure the cloud system to use')
            [CompletionResult]::new('upload', 'upload', [CompletionResultType]::ParameterValue, 'Upload your local backups to the cloud, overwriting any existing cloud backups')
            [CompletionResult]::new('download', 'download', [CompletionResultType]::ParameterValue, 'Download your cloud backups, overwriting any existing local backups')
            break
        }
        'ludusavi;help;cloud;set' {
            [CompletionResult]::new('none', 'none', [CompletionResultType]::ParameterValue, 'Disable cloud backups')
            [CompletionResult]::new('custom', 'custom', [CompletionResultType]::ParameterValue, 'Use a pre-existing Rclone remote')
            [CompletionResult]::new('box', 'box', [CompletionResultType]::ParameterValue, 'Use Box')
            [CompletionResult]::new('dropbox', 'dropbox', [CompletionResultType]::ParameterValue, 'Use Dropbox')
            [CompletionResult]::new('google-drive', 'google-drive', [CompletionResultType]::ParameterValue, 'Use Google Drive')
            [CompletionResult]::new('onedrive', 'onedrive', [CompletionResultType]::ParameterValue, 'Use OneDrive')
            [CompletionResult]::new('ftp', 'ftp', [CompletionResultType]::ParameterValue, 'Use an FTP server')
            [CompletionResult]::new('smb', 'smb', [CompletionResultType]::ParameterValue, 'Use an SMB server')
            [CompletionResult]::new('webdav', 'webdav', [CompletionResultType]::ParameterValue, 'Use a WebDAV server')
            break
        }
        'ludusavi;help;cloud;set;none' {
            break
        }
        'ludusavi;help;cloud;set;custom' {
            break
        }
        'ludusavi;help;cloud;set;box' {
            break
        }
        'ludusavi;help;cloud;set;dropbox' {
            break
        }
        'ludusavi;help;cloud;set;google-drive' {
            break
        }
        'ludusavi;help;cloud;set;onedrive' {
            break
        }
        'ludusavi;help;cloud;set;ftp' {
            break
        }
        'ludusavi;help;cloud;set;smb' {
            break
        }
        'ludusavi;help;cloud;set;webdav' {
            break
        }
        'ludusavi;help;cloud;upload' {
            break
        }
        'ludusavi;help;cloud;download' {
            break
        }
        'ludusavi;help;wrap' {
            break
        }
        'ludusavi;help;api' {
            break
        }
        'ludusavi;help;schema' {
            [CompletionResult]::new('api-input', 'api-input', [CompletionResultType]::ParameterValue, 'Schema for `api` command input')
            [CompletionResult]::new('api-output', 'api-output', [CompletionResultType]::ParameterValue, 'Schema for `api` command output')
            [CompletionResult]::new('config', 'config', [CompletionResultType]::ParameterValue, 'Schema for config.yaml')
            [CompletionResult]::new('general-output', 'general-output', [CompletionResultType]::ParameterValue, 'Schema for general command output in --api mode (`backup`, `restore`, `backups`, `find`, `cloud upload`, `cloud download`)')
            break
        }
        'ludusavi;help;schema;api-input' {
            break
        }
        'ludusavi;help;schema;api-output' {
            break
        }
        'ludusavi;help;schema;config' {
            break
        }
        'ludusavi;help;schema;general-output' {
            break
        }
        'ludusavi;help;gui' {
            break
        }
        'ludusavi;help;help' {
            break
        }
    })

    $completions.Where{ $_.CompletionText -like "$wordToComplete*" } |
        Sort-Object -Property ListItemText
}
