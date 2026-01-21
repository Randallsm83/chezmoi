# Git alias completions
# Proxies git completions to PowerShell wrapper functions

# Map function names to their git subcommand(s)
# Use global scope so the completer scriptblock can access it later
$global:__GitAliasCompletionMap = [System.Collections.Hashtable]::new([System.StringComparer]::Ordinal)

# Get the native git completer (from git-for-windows or PowerShell's built-in)
$gitCompleter = {
    param($wordToComplete, $commandAst, $cursorPosition)
    
    # Build the equivalent git command from the function call
    $funcName = $commandAst.CommandElements[0].Value
    $gitArgs = $global:__GitAliasCompletionMap[$funcName]
    
    if (-not $gitArgs) { return }
    
    # Get the arguments after the function name
    $otherArgs = $commandAst.CommandElements | Select-Object -Skip 1 | ForEach-Object { $_.Extent.Text }
    
    # Build full git command for completion
    $fullCommand = @('git') + $gitArgs + $otherArgs
    $fullCommandLine = $fullCommand -join ' '
    
    # Use git's built-in completion via __git_complete or fallback
    try {
        # Try to get completions from git
        $completions = @()
        
        # Determine what we're completing based on the git subcommand
        $subcommand = $gitArgs[0]
        
        switch ($subcommand) {
            { $_ -in 'checkout', 'switch', 'branch', 'merge', 'rebase', 'diff', 'log', 'show', 'reset', 'cherry-pick', 'revert' } {
                # Complete branch names and refs
                if ($wordToComplete -match '^-') {
                    # Complete flags
                    $completions = git $subcommand --help 2>&1 | Select-String -Pattern '^\s+(-[\w-]+)' -AllMatches | 
                        ForEach-Object { $_.Matches.Groups[1].Value } | Where-Object { $_ -like "$wordToComplete*" }
                } else {
                    # Complete refs (branches, tags, remotes)
                    $completions = @(
                        git for-each-ref --format='%(refname:short)' refs/heads refs/tags refs/remotes 2>$null
                    ) | Where-Object { $_ -like "$wordToComplete*" }
                }
            }
            'add' {
                # Complete files
                $completions = git ls-files --modified --others --exclude-standard 2>$null | 
                    Where-Object { $_ -like "$wordToComplete*" }
            }
            'restore' {
                if ($otherArgs -contains '--staged' -or $otherArgs -contains '-S') {
                    $completions = git diff --cached --name-only 2>$null | Where-Object { $_ -like "$wordToComplete*" }
                } else {
                    $completions = git ls-files --modified 2>$null | Where-Object { $_ -like "$wordToComplete*" }
                }
            }
            'stash' {
                if ($otherArgs.Count -eq 0 -or ($otherArgs.Count -eq 1 -and $wordToComplete)) {
                    $completions = @('push', 'pop', 'apply', 'drop', 'list', 'show', 'clear') | 
                        Where-Object { $_ -like "$wordToComplete*" }
                }
            }
            'remote' {
                if ($otherArgs.Count -eq 0 -or ($otherArgs.Count -eq 1 -and $wordToComplete)) {
                    $completions = @('add', 'remove', 'rename', 'set-url', 'show', 'prune', 'update') | 
                        Where-Object { $_ -like "$wordToComplete*" }
                } else {
                    $completions = git remote 2>$null | Where-Object { $_ -like "$wordToComplete*" }
                }
            }
            'push' {
                if ($otherArgs.Count -eq 0) {
                    $completions = git remote 2>$null | Where-Object { $_ -like "$wordToComplete*" }
                } else {
                    $completions = git for-each-ref --format='%(refname:short)' refs/heads 2>$null | 
                        Where-Object { $_ -like "$wordToComplete*" }
                }
            }
            'pull' {
                if ($otherArgs.Count -eq 0) {
                    $completions = git remote 2>$null | Where-Object { $_ -like "$wordToComplete*" }
                }
            }
            'fetch' {
                $completions = git remote 2>$null | Where-Object { $_ -like "$wordToComplete*" }
            }
            'worktree' {
                if ($otherArgs.Count -eq 0 -or ($otherArgs.Count -eq 1 -and $wordToComplete)) {
                    $completions = @('add', 'list', 'move', 'remove', 'prune', 'lock', 'unlock') | 
                        Where-Object { $_ -like "$wordToComplete*" }
                }
            }
            'tag' {
                $completions = git tag 2>$null | Where-Object { $_ -like "$wordToComplete*" }
            }
            'config' {
                if ($wordToComplete -match '^-') {
                    $completions = @('--list', '--global', '--local', '--system', '--get', '--get-all', '--unset') | 
                        Where-Object { $_ -like "$wordToComplete*" }
                }
            }
            default {
                # Generic ref completion
                $completions = git for-each-ref --format='%(refname:short)' refs/heads refs/tags 2>$null | 
                    Where-Object { $_ -like "$wordToComplete*" }
            }
        }
        
        $completions | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
    }
    catch {
        # Silently fail if git commands error
    }
}

# Map function names to their git subcommand(s)
# Use case-sensitive hashtable since we have gbd/gbD, gcb/gcB
$global:__GitAliasCompletionMap = [System.Collections.Hashtable]::new([System.StringComparer]::Ordinal)

# Status
$global:__GitAliasCompletionMap['gst'] = @('status')
$global:__GitAliasCompletionMap['gs'] = @('status')
$global:__GitAliasCompletionMap['gss'] = @('status', '--short')
$global:__GitAliasCompletionMap['gsb'] = @('status', '--short', '--branch')

# Add
$global:__GitAliasCompletionMap['ga'] = @('add')
$global:__GitAliasCompletionMap['gaa'] = @('add', '--all')
$global:__GitAliasCompletionMap['gapa'] = @('add', '--patch')
$global:__GitAliasCompletionMap['gau'] = @('add', '--update')
$global:__GitAliasCompletionMap['gav'] = @('add', '--verbose')

# Branch
$global:__GitAliasCompletionMap['gb'] = @('branch')
$global:__GitAliasCompletionMap['gba'] = @('branch', '--all')
$global:__GitAliasCompletionMap['gbd'] = @('branch', '--delete')
$global:__GitAliasCompletionMap['gbD'] = @('branch', '--delete', '--force')
$global:__GitAliasCompletionMap['gbm'] = @('branch', '--move')
$global:__GitAliasCompletionMap['gbnm'] = @('branch', '--no-merged')
$global:__GitAliasCompletionMap['gbr'] = @('branch', '--remote')

# Checkout
$global:__GitAliasCompletionMap['gco'] = @('checkout')
$global:__GitAliasCompletionMap['gcor'] = @('checkout', '--recurse-submodules')
$global:__GitAliasCompletionMap['gcb'] = @('checkout', '-b')
$global:__GitAliasCompletionMap['gcB'] = @('checkout', '-B')

# Cherry-pick
$global:__GitAliasCompletionMap['gcp'] = @('cherry-pick')
$global:__GitAliasCompletionMap['gcpa'] = @('cherry-pick', '--abort')
$global:__GitAliasCompletionMap['gcpc'] = @('cherry-pick', '--continue')

# Clone
$global:__GitAliasCompletionMap['gcl'] = @('clone', '--recurse-submodules')
$global:__GitAliasCompletionMap['gclf'] = @('clone')

# Commit
$global:__GitAliasCompletionMap['gc'] = @('commit', '--verbose')
$global:__GitAliasCompletionMap['gca'] = @('commit', '--verbose', '--all')
$global:__GitAliasCompletionMap['gcam'] = @('commit', '--all', '--message')
$global:__GitAliasCompletionMap['gcas'] = @('commit', '--all', '--signoff')
$global:__GitAliasCompletionMap['gcasm'] = @('commit', '--all', '--signoff', '--message')
$global:__GitAliasCompletionMap['gcs'] = @('commit', '--gpg-sign')
$global:__GitAliasCompletionMap['gcss'] = @('commit', '--gpg-sign', '--signoff')
$global:__GitAliasCompletionMap['gcssm'] = @('commit', '--gpg-sign', '--signoff', '--message')
$global:__GitAliasCompletionMap['gcmsg'] = @('commit', '--message')
$global:__GitAliasCompletionMap['gcsm'] = @('commit', '--signoff', '--message')
$global:__GitAliasCompletionMap['gcn'] = @('commit', '--verbose', '--no-edit')

# Config
$global:__GitAliasCompletionMap['gcf'] = @('config', '--list')

# Diff
$global:__GitAliasCompletionMap['gd'] = @('diff')
$global:__GitAliasCompletionMap['gdca'] = @('diff', '--cached')
$global:__GitAliasCompletionMap['gdcw'] = @('diff', '--cached', '--word-diff')
$global:__GitAliasCompletionMap['gds'] = @('diff', '--staged')
$global:__GitAliasCompletionMap['gdw'] = @('diff', '--word-diff')
$global:__GitAliasCompletionMap['gdup'] = @('diff')
$global:__GitAliasCompletionMap['gdt'] = @('diff-tree')

# Fetch
$global:__GitAliasCompletionMap['gf'] = @('fetch')
$global:__GitAliasCompletionMap['gfa'] = @('fetch', '--all', '--tags', '--prune')
$global:__GitAliasCompletionMap['gfo'] = @('fetch', 'origin')

# Help
$global:__GitAliasCompletionMap['ghh'] = @('help')

# Log
$global:__GitAliasCompletionMap['glgg'] = @('log', '--graph')
$global:__GitAliasCompletionMap['glgga'] = @('log', '--graph', '--decorate', '--all')
$global:__GitAliasCompletionMap['glgm'] = @('log', '--graph')
$global:__GitAliasCompletionMap['glods'] = @('log', '--graph')
$global:__GitAliasCompletionMap['glod'] = @('log', '--graph')
$global:__GitAliasCompletionMap['glola'] = @('log', '--graph')
$global:__GitAliasCompletionMap['glols'] = @('log', '--graph')
$global:__GitAliasCompletionMap['glol'] = @('log', '--graph')
$global:__GitAliasCompletionMap['glo'] = @('log', '--oneline', '--decorate')
$global:__GitAliasCompletionMap['glog'] = @('log', '--oneline', '--decorate', '--graph')
$global:__GitAliasCompletionMap['gloga'] = @('log', '--oneline', '--decorate', '--graph', '--all')
$global:__GitAliasCompletionMap['glg'] = @('log', '--stat')
$global:__GitAliasCompletionMap['glgp'] = @('log', '--stat', '--patch')

# Merge
$global:__GitAliasCompletionMap['gm'] = @('merge')
$global:__GitAliasCompletionMap['gma'] = @('merge', '--abort')
$global:__GitAliasCompletionMap['gmc'] = @('merge', '--continue')
$global:__GitAliasCompletionMap['gms'] = @('merge', '--squash')
$global:__GitAliasCompletionMap['gmff'] = @('merge', '--ff-only')
$global:__GitAliasCompletionMap['gmom'] = @('merge')
$global:__GitAliasCompletionMap['gmum'] = @('merge')
$global:__GitAliasCompletionMap['gmtl'] = @('mergetool')
$global:__GitAliasCompletionMap['gmtlvim'] = @('mergetool')

# Pull
$global:__GitAliasCompletionMap['gl'] = @('pull')
$global:__GitAliasCompletionMap['gpr'] = @('pull', '--rebase')
$global:__GitAliasCompletionMap['gprv'] = @('pull', '--rebase', '-v')
$global:__GitAliasCompletionMap['gpra'] = @('pull', '--rebase', '--autostash')
$global:__GitAliasCompletionMap['gprav'] = @('pull', '--rebase', '--autostash', '-v')
$global:__GitAliasCompletionMap['gprom'] = @('pull', '--rebase', 'origin')
$global:__GitAliasCompletionMap['gpromi'] = @('pull')
$global:__GitAliasCompletionMap['gprum'] = @('pull', '--rebase', 'upstream')
$global:__GitAliasCompletionMap['gprumi'] = @('pull')
$global:__GitAliasCompletionMap['ggpull'] = @('pull', 'origin')
$global:__GitAliasCompletionMap['gluc'] = @('pull', 'upstream')
$global:__GitAliasCompletionMap['glum'] = @('pull', 'upstream')

# Push
$global:__GitAliasCompletionMap['gp'] = @('push')
$global:__GitAliasCompletionMap['gpd'] = @('push', '--dry-run')
$global:__GitAliasCompletionMap['gpf'] = @('push', '--force-with-lease')
$global:__GitAliasCompletionMap['gpsup'] = @('push', '--set-upstream', 'origin')
$global:__GitAliasCompletionMap['gpv'] = @('push', '--verbose')
$global:__GitAliasCompletionMap['gpoat'] = @('push')
$global:__GitAliasCompletionMap['gpod'] = @('push', 'origin', '--delete')
$global:__GitAliasCompletionMap['ggpush'] = @('push', 'origin')
$global:__GitAliasCompletionMap['gpu'] = @('push', 'upstream')

# Rebase
$global:__GitAliasCompletionMap['grb'] = @('rebase')
$global:__GitAliasCompletionMap['grba'] = @('rebase', '--abort')
$global:__GitAliasCompletionMap['grbc'] = @('rebase', '--continue')
$global:__GitAliasCompletionMap['grbi'] = @('rebase', '--interactive')
$global:__GitAliasCompletionMap['grbo'] = @('rebase', '--onto')
$global:__GitAliasCompletionMap['grbs'] = @('rebase', '--skip')
$global:__GitAliasCompletionMap['grbd'] = @('rebase')
$global:__GitAliasCompletionMap['grbm'] = @('rebase')
$global:__GitAliasCompletionMap['grbom'] = @('rebase')
$global:__GitAliasCompletionMap['grbum'] = @('rebase')

# Reflog
$global:__GitAliasCompletionMap['grf'] = @('reflog')

# Remote
$global:__GitAliasCompletionMap['gr'] = @('remote')
$global:__GitAliasCompletionMap['grv'] = @('remote', '--verbose')
$global:__GitAliasCompletionMap['gra'] = @('remote', 'add')
$global:__GitAliasCompletionMap['grrm'] = @('remote', 'remove')
$global:__GitAliasCompletionMap['grmv'] = @('remote', 'rename')
$global:__GitAliasCompletionMap['grset'] = @('remote', 'set-url')
$global:__GitAliasCompletionMap['grup'] = @('remote', 'update')

# Reset
$global:__GitAliasCompletionMap['grh'] = @('reset')
$global:__GitAliasCompletionMap['gru'] = @('reset', '--')
$global:__GitAliasCompletionMap['grhh'] = @('reset', '--hard')
$global:__GitAliasCompletionMap['grhk'] = @('reset', '--keep')
$global:__GitAliasCompletionMap['grhs'] = @('reset', '--soft')
$global:__GitAliasCompletionMap['groh'] = @('reset')

# Restore
$global:__GitAliasCompletionMap['grs'] = @('restore')
$global:__GitAliasCompletionMap['grss'] = @('restore', '--source')
$global:__GitAliasCompletionMap['grst'] = @('restore', '--staged')

# Revert
$global:__GitAliasCompletionMap['grev'] = @('revert')
$global:__GitAliasCompletionMap['greva'] = @('revert', '--abort')
$global:__GitAliasCompletionMap['grevc'] = @('revert', '--continue')

# Remove
$global:__GitAliasCompletionMap['grm'] = @('rm')
$global:__GitAliasCompletionMap['grmc'] = @('rm', '--cached')

# Show
$global:__GitAliasCompletionMap['gsh'] = @('show')
$global:__GitAliasCompletionMap['gsps'] = @('show')

# Stash
$global:__GitAliasCompletionMap['gsta'] = @('stash', 'push')
$global:__GitAliasCompletionMap['gstall'] = @('stash', '--all')
$global:__GitAliasCompletionMap['gstaa'] = @('stash', 'apply')
$global:__GitAliasCompletionMap['gstc'] = @('stash', 'clear')
$global:__GitAliasCompletionMap['gstd'] = @('stash', 'drop')
$global:__GitAliasCompletionMap['gstl'] = @('stash', 'list')
$global:__GitAliasCompletionMap['gstp'] = @('stash', 'pop')
$global:__GitAliasCompletionMap['gsts'] = @('stash', 'show')
$global:__GitAliasCompletionMap['gstu'] = @('stash', '--include-untracked')

# Submodule
$global:__GitAliasCompletionMap['gsi'] = @('submodule', 'init')
$global:__GitAliasCompletionMap['gsu'] = @('submodule', 'update')

# Switch
$global:__GitAliasCompletionMap['gsw'] = @('switch')
$global:__GitAliasCompletionMap['gswc'] = @('switch', '--create')
$global:__GitAliasCompletionMap['gswd'] = @('switch')
$global:__GitAliasCompletionMap['gswm'] = @('switch')

# Tag
$global:__GitAliasCompletionMap['gt'] = @('tag')
$global:__GitAliasCompletionMap['gta'] = @('tag', '--annotate')
$global:__GitAliasCompletionMap['gts'] = @('tag', '--sign')
$global:__GitAliasCompletionMap['gtv'] = @('tag')

# Worktree
$global:__GitAliasCompletionMap['gwt'] = @('worktree')
$global:__GitAliasCompletionMap['gwta'] = @('worktree', 'add')
$global:__GitAliasCompletionMap['gwtls'] = @('worktree', 'list')
$global:__GitAliasCompletionMap['gwtmv'] = @('worktree', 'move')
$global:__GitAliasCompletionMap['gwtrm'] = @('worktree', 'remove')

# Register the completer for all mapped functions
$global:__GitAliasCompletionMap.Keys | ForEach-Object {
    Register-ArgumentCompleter -CommandName $_ -ScriptBlock $gitCompleter
}

# vim: ft=ps1 sw=4 ts=4 et
