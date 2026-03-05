# PowerShell Git Aliases
# Comprehensive git aliases matching zsh 85-git.zsh configuration
# Sourced automatically by Microsoft.PowerShell_profile.ps1
#
# Usage: Reload with . $PROFILE

# ================================================================================================
# Git Aliases
# ================================================================================================

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    return
}

# Helper functions
function Get-GitCurrentBranch { git symbolic-ref --short HEAD 2>$null }
function Get-GitMainBranch {
    $refs = @('main', 'trunk', 'mainline', 'default', 'stable', 'master')
    foreach ($ref in $refs) {
        if (git show-ref -q --verify "refs/heads/$ref" 2>$null) { return $ref }
    }
    return 'master'
}
function Get-GitDevelopBranch {
    $branches = @('dev', 'devel', 'develop', 'development')
    foreach ($branch in $branches) {
        if (git show-ref -q --verify "refs/heads/$branch" 2>$null) { return $branch }
    }
    return 'develop'
}

# Root
function grt { Set-Location (git rev-parse --show-toplevel) }

# Status
function gst { git status $args }
function gs { git status $args }
function gss { git status --short $args }
function gsb { git status --short --branch $args }

# Add
function ga { git add $args }
function gaa { git add --all $args }
function gapa { git add --patch $args }
function gau { git add --update $args }
function gav { git add --verbose $args }

# WIP (Work In Progress)
function gwip { git add -A; git rm (git ls-files --deleted) 2>$null; git commit --no-verify --no-gpg-sign --message '--wip-- [skip ci]' }
function gunwip { if ((git log -1 --format='%s') -match '--wip--') { git reset HEAD~1 } }

# Branch
function gb { git branch $args }
function gba { git branch --all $args }
function gbd { git branch --delete $args }
function gbD { git branch --delete --force $args }
function gbm { git branch --move $args }
function gbnm { git branch --no-merged $args }
function gbr { git branch --remote $args }
function ggsup { git branch --set-upstream-to="origin/$(Get-GitCurrentBranch)" }

# Delete merged branches
function gbda {
    $mainBranch = Get-GitMainBranch
    $devBranch = Get-GitDevelopBranch
    git branch --no-color --merged | Where-Object { $_ -notmatch "^\*|^\+|\s*($mainBranch|$devBranch)\s*$" } | ForEach-Object { git branch --delete $_.Trim() 2>$null }
}

# Checkout
function gco { git checkout $args }
function gcor { git checkout --recurse-submodules $args }
function gcb { git checkout -b $args }
function gcB { git checkout -B $args }
function gcm { git checkout (Get-GitMainBranch) }
function gcd { git checkout (Get-GitDevelopBranch) }

# Cherry-pick
function gcp { git cherry-pick $args }
function gcpa { git cherry-pick --abort $args }
function gcpc { git cherry-pick --continue $args }

# Clean
function gclean { git clean --interactive -d $args }

# Clone
function gcl { git clone --recurse-submodules $args }
function gclf { git clone --recursive --shallow-submodules --filter=blob:none --also-filter-submodules $args }
function gccd {
    git clone --recurse-submodules $args
    if ($LASTEXITCODE -eq 0) {
        $repo = $args[-1] -replace '.*/','' -replace '\.git$',''
        if (Test-Path $repo) { Set-Location $repo }
    }
}

# Commit
function gc { git commit --verbose $args }
function gca { git commit --verbose --all $args }
function gcam { git commit --all --message $args }
function gcas { git commit --all --signoff $args }
function gcasm { git commit --all --signoff --message $args }
function gcs { git commit --gpg-sign $args }
function gcss { git commit --gpg-sign --signoff $args }
function gcssm { git commit --gpg-sign --signoff --message $args }
function gcmsg { git commit --message $args }
function gcsm { git commit --signoff --message $args }
Set-Alias -Name 'gca!' -Value 'git commit --verbose --all --amend' -Scope Global
Set-Alias -Name 'gcan!' -Value 'git commit --verbose --all --no-edit --amend' -Scope Global
Set-Alias -Name 'gcans!' -Value 'git commit --verbose --all --signoff --no-edit --amend' -Scope Global
Set-Alias -Name 'gcann!' -Value 'git commit --verbose --all --date=now --no-edit --amend' -Scope Global
Set-Alias -Name 'gc!' -Value 'git commit --verbose --amend' -Scope Global
function gcn { git commit --verbose --no-edit $args }
Set-Alias -Name 'gcn!' -Value 'git commit --verbose --no-edit --amend' -Scope Global

# Config
function gcf { git config --list $args }

# Describe
function gdct { git describe --tags (git rev-list --tags --max-count=1) }

# Diff
function gd { git diff $args }
function gdca { git diff --cached $args }
function gdcw { git diff --cached --word-diff $args }
function gds { git diff --staged $args }
function gdw { git diff --word-diff $args }
function gdup { git diff '@{upstream}' $args }
function gdt { git diff-tree --no-commit-id --name-only -r $args }

# Fetch
function gf { git fetch $args }
function gfa { git fetch --all --tags --prune --jobs=10 $args }
function gfo { git fetch origin $args }

# Help
function ghh { git help $args }

# Log
function glgg { git log --graph $args }
function glgga { git log --graph --decorate --all $args }
function glgm { git log --graph --max-count=10 $args }
function glods { git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ad) %C(bold blue)`<%an`>%Creset' --date=short $args }
function glod { git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ad) %C(bold blue)`<%an`>%Creset' $args }
function glola { git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)`<%an`>%Creset' --all $args }
function glols { git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)`<%an`>%Creset' --stat $args }
function glol { git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)`<%an`>%Creset' $args }
function glo { git log --oneline --decorate $args }
function glog { git log --oneline --decorate --graph $args }
function gloga { git log --oneline --decorate --graph --all $args }
function glg { git log --stat $args }
function glgp { git log --stat --patch $args }

# List files
function gfg { git ls-files | Select-String $args }

# Merge
function gm { git merge $args }
function gma { git merge --abort $args }
function gmc { git merge --continue $args }
function gms { git merge --squash $args }
function gmff { git merge --ff-only $args }
function gmom { git merge "origin/$(Get-GitMainBranch)" $args }
function gmum { git merge "upstream/$(Get-GitMainBranch)" $args }
function gmtl { git mergetool --no-prompt $args }
function gmtlvim { git mergetool --no-prompt --tool=vimdiff $args }

# Pull
function gl { git pull $args }
function gpr { git pull --rebase $args }
function gprv { git pull --rebase -v $args }
function gpra { git pull --rebase --autostash $args }
function gprav { git pull --rebase --autostash -v $args }
function gprom { git pull --rebase origin (Get-GitMainBranch) $args }
function gpromi { git pull --rebase=interactive origin (Get-GitMainBranch) $args }
function gprum { git pull --rebase upstream (Get-GitMainBranch) $args }
function gprumi { git pull --rebase=interactive upstream (Get-GitMainBranch) $args }
function ggpull { git pull origin (Get-GitCurrentBranch) $args }
function gluc { git pull upstream (Get-GitCurrentBranch) $args }
function glum { git pull upstream (Get-GitMainBranch) $args }

# Push
function gp { git push $args }
function gpd { git push --dry-run $args }
function gpf { git push --force-with-lease $args }
Set-Alias -Name 'gpf!' -Value 'git push --force' -Scope Global
function gpsup { git push --set-upstream origin (Get-GitCurrentBranch) $args }
function gpv { git push --verbose $args }
function gpoat { git push origin --all; git push origin --tags }
function gpod { git push origin --delete $args }
function ggpush { git push origin (Get-GitCurrentBranch) $args }
function gpu { git push upstream $args }

# Rebase
function grb { git rebase $args }
function grba { git rebase --abort $args }
function grbc { git rebase --continue $args }
function grbi { git rebase --interactive $args }
function grbo { git rebase --onto $args }
function grbs { git rebase --skip $args }
function grbd { git rebase (Get-GitDevelopBranch) $args }
function grbm { git rebase (Get-GitMainBranch) $args }
function grbom { git rebase "origin/$(Get-GitMainBranch)" $args }
function grbum { git rebase "upstream/$(Get-GitMainBranch)" $args }

# Reflog
function grf { git reflog $args }

# Remote
function gr { git remote $args }
function grv { git remote --verbose $args }
function gra { git remote add $args }
function grrm { git remote remove $args }
function grmv { git remote rename $args }
function grset { git remote set-url $args }
function grup { git remote update $args }

# Reset
function grh { git reset $args }
function gru { git reset -- $args }
function grhh { git reset --hard $args }
function grhk { git reset --keep $args }
function grhs { git reset --soft $args }
function gpristine { git reset --hard; git clean --force -dfx }
function gwipe { git reset --hard; git clean --force -df }
function groh { git reset "origin/$(Get-GitCurrentBranch)" --hard $args }

# Restore
function grs { git restore $args }
function grss { git restore --source $args }
function grst { git restore --staged $args }

# Revert
function grev { git revert $args }
function greva { git revert --abort $args }
function grevc { git revert --continue $args }

# Remove
function grm { git rm $args }
function grmc { git rm --cached $args }

# Show
function gsh { git show $args }
function gsps { git show --pretty=short --show-signature $args }

# Shortlog
function gcount { git shortlog --summary --numbered $args }

# Stash
function gsta { git stash push $args }
function gstall { git stash --all $args }
function gstaa { git stash apply $args }
function gstc { git stash clear $args }
function gstd { git stash drop $args }
function gstl { git stash list $args }
function gstp { git stash pop $args }
function gsts { git stash show --patch $args }
function gstu { git stash --include-untracked $args }

# Submodule
function gsi { git submodule init $args }
function gsu { git submodule update $args }

# Switch
function gsw { git switch $args }
function gswc { git switch --create $args }
function gswd { git switch (Get-GitDevelopBranch) $args }
function gswm { git switch (Get-GitMainBranch) $args }

# Tag
function gt { git tag $args }
function gta { git tag --annotate $args }
function gts { git tag --sign $args }
function gtv { git tag | Sort-Object { [version]($_ -replace '^v', '') } $args }

# Update-index
function gignore { git update-index --assume-unchanged $args }
function gunignore { git update-index --no-assume-unchanged $args }

# Whatchanged
function gwch { git whatchanged -p --abbrev-commit --pretty=medium $args }

# Worktree
function gwt { git worktree $args }
function gwta { git worktree add $args }
function gwtls { git worktree list $args }
function gwtmv { git worktree move $args }
function gwtrm { git worktree remove $args }

# Git grep
function gg { git grep -E $args }

# Run git command in all project directories
function dhgitall {
    if (-not (Test-Path $env:PROJECTS)) {
        Write-Warning "Projects directory not found: $env:PROJECTS"
        return
    }

    Get-ChildItem -Path $env:PROJECTS -Directory | ForEach-Object {
        $projectPath = $_.FullName
        $projectName = $_.Name

        if (Test-Path (Join-Path $projectPath '.git')) {
            Write-Host "`n=== $projectName ===" -ForegroundColor Cyan
            Push-Location $projectPath
            try {
                git $args
            }
            catch {
                Write-Warning "Error in $projectName : $_"
            }
            finally {
                Pop-Location
            }
        }
    }
}

# ================================================================================================
# Backfilled from zsh 85-git.zsh
# ================================================================================================

function g { git $args }

function grename {
    param([string]$OldBranch, [string]$NewBranch)
    if (-not $OldBranch -or -not $NewBranch) {
        Write-Host "Usage: grename old_branch new_branch"; return
    }
    git branch -m $OldBranch $NewBranch
    if (git push origin ":$OldBranch" 2>$null) {
        git push --set-upstream origin $NewBranch
    }
}
function gbds {
    $defaultBranch = Get-GitMainBranch
    git for-each-ref refs/heads/ "--format=%(refname:short)" | ForEach-Object {
        $branch = $_
        $mergeBase = git merge-base $defaultBranch $branch
        $cherry = git cherry $defaultBranch (git commit-tree (git rev-parse "$branch^{tree}") -p $mergeBase -m "_")
        if ($cherry -match '^-') { git branch -D $branch }
    }
}

function gbg { git branch -vv | Select-String ': gone]' }
function gbgd { git branch --no-color -vv | Select-String ': gone]' | ForEach-Object { ($_ -split '\s+')[1] } | ForEach-Object { git branch -d $_ } }
function gbgD { git branch --no-color -vv | Select-String ': gone]' | ForEach-Object { ($_ -split '\s+')[1] } | ForEach-Object { git branch -D $_ } }
function gignored { git ls-files -v | Select-String '^[a-z]' }
function gdnolock { git diff $args ':(exclude)package-lock.json' ':(exclude)*.lock' }
function gbl { git blame -w $args }
function ggl {
    $b = if ($args.Count -eq 0) { Get-GitCurrentBranch } else { $args[0] }
    git pull origin $b
}

function ggp {
    $b = if ($args.Count -eq 0) { Get-GitCurrentBranch } else { $args[0] }
    git push origin $b
}

function ggf {
    $b = if ($args.Count -eq 0) { Get-GitCurrentBranch } else { $args[0] }
    git push --force origin $b
}

function ggfl {
    $b = if ($args.Count -eq 0) { Get-GitCurrentBranch } else { $args[0] }
    git push --force-with-lease origin $b
}

function ggpnp {
    if ($args.Count -eq 0) { ggl; ggp } else { ggl @args; ggp @args }
}

function ggu {
    $b = if ($args.Count -ne 1) { Get-GitCurrentBranch } else { $args[0] }
    git pull --rebase origin $b
}

function gpsupf { git push --set-upstream origin (Get-GitCurrentBranch) --force-with-lease $args }
function gam { git am $args }
function gama { git am --abort $args }
function gamc { git am --continue $args }
function gamscp { git am --show-current-patch $args }
function gams { git am --skip $args }
function gap { git apply $args }
function gapt { git apply --3way $args }
function gbs { git bisect $args }
function gbsb { git bisect bad $args }
function gbsg { git bisect good $args }
function gbsn { git bisect new $args }
function gbso { git bisect old $args }
function gbsr { git bisect reset $args }
function gbss { git bisect start $args }

function gtl {
    param([string]$Pattern = '')
    git tag --sort=-v:refname -n --list "$Pattern*"
}

function work_in_progress {
    $msg = git -c log.showSignature=false log -n 1 --format='%s' 2>$null
    if ($msg -match '--wip--') { Write-Host 'WIP!!' }
}

function gunwipall {
    $commit = git log --grep='--wip--' --invert-grep --max-count=1 --format=format:%H
    if ($commit -ne (git rev-parse HEAD)) { git reset $commit }
}




# -------------------------------------------------------------------------------------------------
# vim: ft=ps1 sw=4 ts=4 et
