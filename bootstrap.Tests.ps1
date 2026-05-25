#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }
<#
.SYNOPSIS
    Pester 5.x test suite for bootstrap.ps1.
.DESCRIPTION
    Sources the canonical bootstrap script (bootstrap.ps1) and exercises its
    helper functions without touching the host. The Main entrypoint is
    stripped before sourcing so dot-sourcing does not actually bootstrap the
    machine. Every external mutation (chezmoi/scoop/winget/op invocations,
    Set-ItemProperty, Invoke-RestMethod, [Environment]::SetEnvironmentVariable)
    is mocked or stubbed.

.NOTES
    Run with: Invoke-Pester -Path .\bootstrap.Tests.ps1 -Output Detailed

    NOTE: This file targets Pester 5.x. Earlier Pester versions (3.x) do not
    understand the BeforeAll / Mock -ParameterFilter semantics used here.
    Install with:
        Install-Module Pester -MinimumVersion 5.0.0 -Force -Scope CurrentUser -SkipPublisherCheck
#>

BeforeAll {
    # Source the canonical bootstrap script.
    $scriptPath = Join-Path $PSScriptRoot 'bootstrap.ps1'

    # Strip the bottom-of-file `if ($MyInvocation.InvocationName -ne '.') { Main }`
    # block so sourcing does NOT trigger the real Main flow.
    $scriptContent = Get-Content $scriptPath -Raw
    $scriptContent = $scriptContent -replace '(?s)if \(\$MyInvocation\.InvocationName -ne ''\.''\) \{[^}]+\}', ''

    # Source into the current scope so all helpers (Write-Status,
    # Test-CommandExists, Install-Chezmoi, etc.) are callable from tests.
    . ([scriptblock]::Create($scriptContent))
}

Describe 'Test-CommandExists' {
    Context 'When command exists' {
        It 'Returns $true for a built-in PowerShell command' {
            Test-CommandExists 'Get-Process' | Should -Be $true
        }
    }

    Context 'When command does not exist' {
        It 'Returns $false for a nonsense command name' {
            Test-CommandExists 'definitely-not-a-real-command-zzzz' | Should -Be $false
        }

        It 'Does not throw on an empty command name' {
            { Test-CommandExists '' } | Should -Not -Throw
        }
    }
}

Describe 'Test-DeveloperMode' {
    Context 'When the registry value is 1' {
        BeforeAll {
            Mock Get-ItemProperty {
                [pscustomobject]@{ AllowDevelopmentWithoutDevLicense = 1 }
            }
        }

        It 'Returns $true' {
            Test-DeveloperMode | Should -Be $true
        }
    }

    Context 'When the registry value is 0' {
        BeforeAll {
            Mock Get-ItemProperty {
                [pscustomobject]@{ AllowDevelopmentWithoutDevLicense = 0 }
            }
        }

        It 'Returns $false' {
            Test-DeveloperMode | Should -Be $false
        }
    }

    Context 'When the registry key is missing' {
        BeforeAll {
            Mock Get-ItemProperty { $null }
        }

        It 'Returns $false' {
            Test-DeveloperMode | Should -Be $false
        }
    }

    Context 'When Get-ItemProperty throws' {
        BeforeAll {
            Mock Get-ItemProperty { throw 'Access denied' }
        }

        It 'Catches the error and returns $false' {
            Test-DeveloperMode | Should -Be $false
        }
    }
}

Describe 'Enable-DeveloperMode' {
    # Enable-DeveloperMode short-circuits when the principal is not in the
    # Administrator role. We cannot safely cross that branch in test (it
    # would actually flip the dev-mode registry key on the host), so we only
    # assert the non-admin guard on hosts where the runner is not elevated.
    $script:IsRunnerAdmin = ([Security.Principal.WindowsPrincipal]::new(
            [Security.Principal.WindowsIdentity]::GetCurrent()
        )).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    Context 'When not running as administrator' {
        BeforeAll {
            Mock Set-ItemProperty {}
            Mock New-Item         {}
        }

        It 'Returns $false and does not touch the registry' -Skip:$script:IsRunnerAdmin {
            Enable-DeveloperMode | Should -Be $false
            Should -Not -Invoke Set-ItemProperty
        }
    }
}

Describe 'Test-OnePasswordCLI' {
    Context 'When op is not on PATH' {
        BeforeAll {
            Mock Test-CommandExists { $false } -ParameterFilter { $Command -eq 'op' }
        }

        It 'Reports CLI as unavailable' {
            $result = Test-OnePasswordCLI
            $result.Available     | Should -Be $false
            $result.Authenticated | Should -Be $false
            $result.Message       | Should -Match 'not installed'
        }
    }

    Context 'When op is on PATH and authenticated' {
        BeforeAll {
            Mock Test-CommandExists { $true } -ParameterFilter { $Command -eq 'op' }
            function global:op { '[]' }  # Pretend item list returns JSON.
        }

        AfterAll {
            Remove-Item function:global:op -ErrorAction SilentlyContinue
        }

        It 'Reports CLI as authenticated' {
            $result = Test-OnePasswordCLI
            $result.Available     | Should -Be $true
            $result.Authenticated | Should -Be $true
        }
    }
}

Describe 'Invoke-PreflightChecks' {
    BeforeEach {
        $Script:Stats = @{
            PreflightPassed       = $false
            DevModeEnabled        = $false
            OnePasswordAvailable  = $false
        }
    }

    Context 'When every check passes' {
        BeforeAll {
            Mock Test-DeveloperMode    { $true }
            Mock Invoke-WebRequest     { @{ StatusCode = 200 } }
            Mock Test-CommandExists    { $true }
            Mock Test-OnePasswordCLI   { @{ Available = $true; Authenticated = $true; Message = 'ok' } }
            Mock Read-Host             { 'n' }
        }

        It 'Returns $true' {
            Invoke-PreflightChecks | Should -Be $true
            $Script:Stats.PreflightPassed | Should -Be $true
        }
    }

    Context 'When github.com is unreachable' {
        BeforeAll {
            Mock Test-DeveloperMode    { $true }
            Mock Invoke-WebRequest     { throw 'no internet' }
            Mock Test-CommandExists    { $true }
            Mock Test-OnePasswordCLI   { @{ Available = $true; Authenticated = $true; Message = 'ok' } }
        }

        It 'Returns $false' {
            Invoke-PreflightChecks | Should -Be $false
        }
    }
}

Describe 'Import-ScoopExport' {
    Context 'When the export file does not exist' {
        BeforeAll {
            Mock Test-Path { $false } -ParameterFilter { $Path -eq 'C:\nope.json' }
        }

        It 'Returns $false' {
            Import-ScoopExport -ExportFile 'C:\nope.json' | Should -Be $false
        }
    }

    Context 'When scoop is not installed' {
        BeforeAll {
            Mock Test-Path           { $true }
            Mock Test-CommandExists  { $false } -ParameterFilter { $Command -eq 'scoop' }
        }

        It 'Returns $false' {
            Import-ScoopExport -ExportFile 'C:\export.json' | Should -Be $false
        }
    }

    Context 'When scoop is present and the export parses' {
        BeforeAll {
            Mock Test-Path           { $true }
            Mock Test-CommandExists  { $true } -ParameterFilter { $Command -eq 'scoop' }
            Mock Get-Content         { '{"apps":[{"Name":"chezmoi"}],"buckets":[{"Name":"main"}]}' }
            function global:scoop { param([string]$action, [string]$file) }
        }

        AfterAll {
            Remove-Item function:global:scoop -ErrorAction SilentlyContinue
        }

        It 'Returns $true on success' {
            Import-ScoopExport -ExportFile 'C:\export.json' | Should -Be $true
        }
    }
}

Describe 'Import-WingetExport' {
    Context 'When the export file is missing' {
        BeforeAll {
            Mock Test-Path { $false }
        }

        It 'Returns $false' {
            Import-WingetExport -ExportFile 'C:\winget.json' | Should -Be $false
        }
    }

    Context 'When winget is not installed' {
        BeforeAll {
            Mock Test-Path           { $true }
            Mock Test-CommandExists  { $false } -ParameterFilter { $Command -eq 'winget' }
        }

        It 'Returns $false' {
            Import-WingetExport -ExportFile 'C:\winget.json' | Should -Be $false
        }
    }

    Context 'When winget runs successfully' {
        BeforeAll {
            Mock Test-Path           { $true }
            Mock Test-CommandExists  { $true } -ParameterFilter { $Command -eq 'winget' }
            function global:winget { param([Parameter(ValueFromRemainingArguments)]$rest) }
        }

        AfterAll {
            Remove-Item function:global:winget -ErrorAction SilentlyContinue
        }

        It 'Returns $true' {
            Import-WingetExport -ExportFile 'C:\winget.json' | Should -Be $true
        }
    }
}

Describe 'Install-Chezmoi' {
    BeforeEach {
        $Script:Stats = @{
            ChezmoiInstalled = $false
            ScoopInstalled   = $false
            ConfigsApplied   = $false
        }
    }

    Context 'When chezmoi is already installed' {
        BeforeAll {
            Mock Test-CommandExists { $true } -ParameterFilter { $Command -eq 'chezmoi' }
        }

        It 'Reports installed without attempting install' {
            Install-Chezmoi | Should -Be $true
            $Script:Stats.ChezmoiInstalled | Should -Be $true
        }
    }

    Context 'When scoop is available' {
        BeforeAll {
            Mock Test-CommandExists { $false } -ParameterFilter { $Command -eq 'chezmoi' }
            Mock Test-CommandExists { $true }  -ParameterFilter { $Command -eq 'scoop' }
            function global:scoop { param($action, $package) }
        }

        AfterAll {
            Remove-Item function:global:scoop -ErrorAction SilentlyContinue
        }

        It 'Installs chezmoi via scoop' {
            Install-Chezmoi | Should -Be $true
            $Script:Stats.ChezmoiInstalled | Should -Be $true
        }
    }

    Context 'When no package manager is available' {
        BeforeAll {
            Mock Test-CommandExists { $false }
        }

        It 'Returns $false' {
            Install-Chezmoi | Should -Be $false
            $Script:Stats.ChezmoiInstalled | Should -Be $false
        }
    }
}

Describe 'Install-Scoop' {
    BeforeEach {
        $Script:Stats = @{ ScoopInstalled = $false }
    }

    Context 'When scoop is already installed' {
        BeforeAll {
            Mock Test-CommandExists { $true } -ParameterFilter { $Command -eq 'scoop' }
            Mock Invoke-RestMethod {}
        }

        It 'Returns $true without re-running the installer' {
            Install-Scoop | Should -Be $true
            Should -Not -Invoke Invoke-RestMethod
        }
    }

    Context 'When scoop is not installed and the installer succeeds' {
        BeforeAll {
            Mock Test-CommandExists { $false } -ParameterFilter { $Command -eq 'scoop' }
            Mock Get-ExecutionPolicy { 'RemoteSigned' }
            Mock Invoke-RestMethod   { 'fake-installer-script' }
            Mock Invoke-Expression   { $Script:Stats.ScoopInstalled = $true }
        }

        It 'Downloads from the official URL and reports success' {
            Install-Scoop | Should -Be $true
            Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter { $Uri -eq 'https://get.scoop.sh' }
        }
    }

    Context 'When the installer throws' {
        BeforeAll {
            Mock Test-CommandExists { $false } -ParameterFilter { $Command -eq 'scoop' }
            Mock Get-ExecutionPolicy { 'RemoteSigned' }
            Mock Invoke-RestMethod   { throw 'network error' }
        }

        It 'Returns $false' {
            Install-Scoop | Should -Be $false
            $Script:Stats.ScoopInstalled | Should -Be $false
        }
    }
}

Describe 'Initialize-Chezmoi (HTTPS default + -UseSSH fallback)' {
    BeforeEach {
        $Script:Stats = @{ ConfigsApplied = $false }
        $script:CapturedUrls = [System.Collections.Generic.List[string]]::new()
    }

    Context 'Default behavior (no -UseSSH)' {
        BeforeAll {
            function global:chezmoi {
                # chezmoi init --apply --branch <branch> <url>
                # Capture the URL (last positional arg) and exit 0.
                $script:CapturedUrls.Add($args[-1])
                $global:LASTEXITCODE = 0
            }
        }

        AfterAll {
            Remove-Item function:global:chezmoi -ErrorAction SilentlyContinue
        }

        It 'Clones via HTTPS for a shorthand owner/repo' {
            Initialize-Chezmoi -Repo 'octocat/Hello-World' -Branch 'main' | Should -Be $true
            $script:CapturedUrls.Count | Should -Be 1
            $script:CapturedUrls[0]    | Should -Be 'https://github.com/octocat/Hello-World.git'
            $Script:Stats.ConfigsApplied | Should -Be $true
        }
    }

    Context 'With -UseSSH and a working SSH agent' {
        BeforeAll {
            function global:chezmoi {
                $script:CapturedUrls.Add($args[-1])
                $global:LASTEXITCODE = 0
            }
        }

        AfterAll {
            Remove-Item function:global:chezmoi -ErrorAction SilentlyContinue
        }

        It 'Uses the SSH URL and stops there' {
            Initialize-Chezmoi -Repo 'octocat/Hello-World' -Branch 'main' -UseSSH | Should -Be $true
            $script:CapturedUrls[0]    | Should -Be 'git@github.com:octocat/Hello-World.git'
            $script:CapturedUrls.Count | Should -Be 1
        }
    }

    Context 'With -UseSSH but the SSH clone fails' {
        BeforeAll {
            # First call fails (SSH), second call succeeds (HTTPS).
            function global:chezmoi {
                $script:CapturedUrls.Add($args[-1])
                if ($args[-1] -like 'git@*') {
                    $global:LASTEXITCODE = 128
                } else {
                    $global:LASTEXITCODE = 0
                }
            }
        }

        AfterAll {
            Remove-Item function:global:chezmoi -ErrorAction SilentlyContinue
        }

        It 'Falls back to HTTPS and reports success' {
            Initialize-Chezmoi -Repo 'octocat/Hello-World' -Branch 'main' -UseSSH | Should -Be $true
            $script:CapturedUrls.Count | Should -Be 2
            $script:CapturedUrls[0]    | Should -Match '^git@github\.com:'
            $script:CapturedUrls[1]    | Should -Be 'https://github.com/octocat/Hello-World.git'
            $Script:Stats.ConfigsApplied | Should -Be $true
        }
    }

    Context 'When both SSH and HTTPS fail' {
        BeforeAll {
            function global:chezmoi {
                $script:CapturedUrls.Add($args[-1])
                $global:LASTEXITCODE = 128
            }
        }

        AfterAll {
            Remove-Item function:global:chezmoi -ErrorAction SilentlyContinue
        }

        It 'Returns $false and leaves ConfigsApplied $false' {
            Initialize-Chezmoi -Repo 'octocat/Hello-World' -Branch 'main' -UseSSH | Should -Be $false
            $script:CapturedUrls.Count | Should -Be 2
            $Script:Stats.ConfigsApplied | Should -Be $false
        }
    }

    Context 'With an explicit full URL' {
        BeforeAll {
            function global:chezmoi {
                $script:CapturedUrls.Add($args[-1])
                $global:LASTEXITCODE = 0
            }
        }

        AfterAll {
            Remove-Item function:global:chezmoi -ErrorAction SilentlyContinue
        }

        It 'Passes the URL through unchanged' {
            $url = 'https://gitlab.example.com/me/dotfiles.git'
            Initialize-Chezmoi -Repo $url -Branch 'main' | Should -Be $true
            $script:CapturedUrls[0] | Should -Be $url
        }
    }
}

Describe 'Set-EnvironmentVariables' {
    BeforeEach {
        # Snapshot the user's current XDG vars so the test cannot leak.
        $script:BackupEnv = @{
            XDG_CONFIG_HOME = $env:XDG_CONFIG_HOME
            XDG_DATA_HOME   = $env:XDG_DATA_HOME
            XDG_STATE_HOME  = $env:XDG_STATE_HOME
            XDG_CACHE_HOME  = $env:XDG_CACHE_HOME
        }
        # Suppress the persistent (User-scope) write so the test does not
        # mutate the host registry.
        Mock New-Item {}
    }

    AfterEach {
        foreach ($k in $script:BackupEnv.Keys) {
            Set-Item -Path "env:$k" -Value $script:BackupEnv[$k]
        }
    }

    It 'Sets all four XDG variables for the current session' {
        Set-EnvironmentVariables
        $env:XDG_CONFIG_HOME | Should -Be "$env:USERPROFILE\.config"
        $env:XDG_DATA_HOME   | Should -Be "$env:USERPROFILE\.local\share"
        $env:XDG_STATE_HOME  | Should -Be "$env:USERPROFILE\.local\state"
        $env:XDG_CACHE_HOME  | Should -Be "$env:USERPROFILE\.cache"
    }
}

# vim: ts=2 sts=2 sw=2 et
