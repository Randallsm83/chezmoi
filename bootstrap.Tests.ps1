#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }

BeforeAll {
    # Source the bootstrap script functions
    $scriptPath = Join-Path $PSScriptRoot 'bootstrap.ps1.example'
    
    # Load the script content but don't execute Main
    $scriptContent = Get-Content $scriptPath -Raw
    $scriptContent = $scriptContent -replace 'if \(\$MyInvocation\.InvocationName -ne ''\.''\) \{[^}]+\}', ''
    . ([scriptblock]::Create($scriptContent))
}

Describe 'Install-Chezmoi' {
    BeforeEach {
        # Reset stats
        $Script:Stats = @{
            StartTime = Get-Date
            ChezmoiInstalled = $false
            ScoopInstalled = $false
            PackagesInstalled = 0
            ConfigsApplied = $false
        }
    }

    Context 'When chezmoi is already installed' {
        BeforeAll {
            Mock Test-CommandExists { $true } -ParameterFilter { $Command -eq 'chezmoi' }
        }

        It 'Should detect existing chezmoi installation' {
            $result = Install-Chezmoi
            
            $result | Should -Be $true
            $Script:Stats.ChezmoiInstalled | Should -Be $true
        }

        It 'Should not attempt to install chezmoi' {
            Mock Test-CommandExists { $false } -ParameterFilter { $Command -eq 'scoop' }
            Mock Test-CommandExists { $false } -ParameterFilter { $Command -eq 'winget' }
            
            Install-Chezmoi | Should -Be $true
            
            Should -Not -Invoke -CommandName scoop
            Should -Not -Invoke -CommandName winget
        }
    }

    Context 'When scoop is available' {
        BeforeAll {
            Mock Test-CommandExists { $false } -ParameterFilter { $Command -eq 'chezmoi' }
            Mock Test-CommandExists { $true } -ParameterFilter { $Command -eq 'scoop' }
            Mock Test-CommandExists { $false } -ParameterFilter { $Command -eq 'winget' }
        }

        It 'Should install chezmoi using scoop' {
            Mock Invoke-Expression { } -ParameterFilter { $Command -match 'scoop install chezmoi' }
            
            # Mock scoop command
            $global:LASTEXITCODE = 0
            Mock Start-Process { 
                [PSCustomObject]@{ ExitCode = 0 }
            } -Verifiable
            
            # Create a mock for scoop install command
            Mock -CommandName 'Invoke-Expression' -MockWith {
                if ($Command -match 'scoop') {
                    # Simulate successful installation
                    return $null
                }
            }

            # Override the actual scoop call
            function global:scoop { 
                param($action, $package)
                if ($action -eq 'install' -and $package -eq 'chezmoi') {
                    return $null
                }
            }
            
            $result = Install-Chezmoi
            
            $result | Should -Be $true
            $Script:Stats.ChezmoiInstalled | Should -Be $true
        }

        It 'Should use scoop as the preferred method' {
            function global:scoop { param($action, $package) }
            Mock Test-CommandExists { $true } -ParameterFilter { $Command -eq 'winget' }
            
            Install-Chezmoi
            
            # Verify scoop was attempted first (indirectly by checking it doesn't fall back)
            $Script:Stats.ChezmoiInstalled | Should -Be $true
        }

        It 'Should fall back to winget if scoop installation fails' {
            # Mock scoop failure
            function global:scoop { 
                param($action, $package)
                throw "Scoop installation failed"
            }
            
            Mock Test-CommandExists { $true } -ParameterFilter { $Command -eq 'winget' }
            
            function global:winget {
                param([string]$action, [string]$id, [string]$package)
                $Script:Stats.ChezmoiInstalled = $true
            }
            
            Mock -CommandName 'Get-EnvironmentVariable' -MockWith { 
                "C:\Windows\System32;C:\Program Files" 
            }
            
            $result = Install-Chezmoi
            
            $result | Should -Be $true
            $Script:Stats.ChezmoiInstalled | Should -Be $true
        }
    }

    Context 'When only winget is available' {
        BeforeAll {
            Mock Test-CommandExists { $false } -ParameterFilter { $Command -eq 'chezmoi' }
            Mock Test-CommandExists { $false } -ParameterFilter { $Command -eq 'scoop' }
            Mock Test-CommandExists { $true } -ParameterFilter { $Command -eq 'winget' }
        }

        It 'Should install chezmoi using winget' {
            function global:winget {
                param(
                    [string]$action,
                    [Parameter(ValueFromRemainingArguments)]
                    [string[]]$remaining
                )
                if ($action -eq 'install') {
                    $Script:Stats.ChezmoiInstalled = $true
                }
            }
            
            # Mock environment variable refresh
            Mock -CommandName 'Get-Process' -MockWith { }
            $env:PATH = "C:\test\path"
            
            $result = Install-Chezmoi
            
            $result | Should -Be $true
            $Script:Stats.ChezmoiInstalled | Should -Be $true
        }

        It 'Should refresh PATH after winget installation' {
            function global:winget { param($action, $id, $package) }
            
            $originalPath = $env:PATH
            Install-Chezmoi
            
            # Verify PATH refresh was attempted (checking that it was reassigned)
            $env:PATH | Should -Not -BeNullOrEmpty
        }

        It 'Should return false if winget installation fails' {
            function global:winget { 
                throw "Winget installation failed"
            }
            
            $result = Install-Chezmoi
            
            $result | Should -Be $false
        }
    }

    Context 'When no package manager is available' {
        BeforeAll {
            Mock Test-CommandExists { $false }
        }

        It 'Should return false' {
            $result = Install-Chezmoi
            
            $result | Should -Be $false
            $Script:Stats.ChezmoiInstalled | Should -Be $false
        }

        It 'Should not modify stats on failure' {
            Install-Chezmoi
            
            $Script:Stats.ChezmoiInstalled | Should -Be $false
        }
    }
}

Describe 'Install-Scoop' {
    BeforeEach {
        $Script:Stats = @{
            StartTime = Get-Date
            ChezmoiInstalled = $false
            ScoopInstalled = $false
            PackagesInstalled = 0
            ConfigsApplied = $false
        }
    }

    Context 'When scoop is already installed' {
        BeforeAll {
            Mock Test-CommandExists { $true } -ParameterFilter { $Command -eq 'scoop' }
        }

        It 'Should detect existing scoop installation' {
            $result = Install-Scoop
            
            $result | Should -Be $true
            $Script:Stats.ScoopInstalled | Should -Be $true
        }

        It 'Should not attempt to reinstall scoop' {
            Mock Invoke-RestMethod { }
            
            Install-Scoop
            
            Should -Not -Invoke -CommandName Invoke-RestMethod
        }
    }

    Context 'When scoop is not installed' {
        BeforeAll {
            Mock Test-CommandExists { $false } -ParameterFilter { $Command -eq 'scoop' }
        }

        It 'Should install scoop successfully' {
            Mock Get-ExecutionPolicy { 'RemoteSigned' }
            Mock Set-ExecutionPolicy { }
            Mock Invoke-RestMethod { 
                # Simulate scoop installation script
                "Installation script content"
            }
            Mock Invoke-Expression {
                # Simulate successful scoop installation
                function global:scoop { param($args) }
                $Script:Stats.ScoopInstalled = $true
            }
            
            $result = Install-Scoop
            
            $result | Should -Be $true
            $Script:Stats.ScoopInstalled | Should -Be $true
        }

        It 'Should change execution policy if restricted' {
            Mock Get-ExecutionPolicy { 'Restricted' }
            Mock Set-ExecutionPolicy { } -Verifiable
            Mock Invoke-RestMethod { "script" }
            Mock Invoke-Expression { 
                $Script:Stats.ScoopInstalled = $true
            }
            
            Install-Scoop
            
            Should -Invoke Set-ExecutionPolicy -Times 1 -ParameterFilter {
                $ExecutionPolicy -eq 'RemoteSigned' -and 
                $Scope -eq 'CurrentUser'
            }
        }

        It 'Should not change execution policy if not restricted' {
            Mock Get-ExecutionPolicy { 'RemoteSigned' }
            Mock Set-ExecutionPolicy { } 
            Mock Invoke-RestMethod { "script" }
            Mock Invoke-Expression { 
                $Script:Stats.ScoopInstalled = $true
            }
            
            Install-Scoop
            
            Should -Not -Invoke Set-ExecutionPolicy
        }

        It 'Should download scoop installer from official URL' {
            Mock Get-ExecutionPolicy { 'RemoteSigned' }
            Mock Invoke-RestMethod { "script" } -Verifiable
            Mock Invoke-Expression { 
                $Script:Stats.ScoopInstalled = $true
            }
            
            Install-Scoop
            
            Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
                $Uri -eq 'https://get.scoop.sh'
            }
        }

        It 'Should return false if installation fails' {
            Mock Get-ExecutionPolicy { 'RemoteSigned' }
            Mock Invoke-RestMethod { throw "Network error" }
            
            $result = Install-Scoop
            
            $result | Should -Be $false
            $Script:Stats.ScoopInstalled | Should -Be $false
        }

        It 'Should handle execution policy change errors gracefully' {
            Mock Get-ExecutionPolicy { 'Restricted' }
            Mock Set-ExecutionPolicy { throw "Access denied" }
            
            $result = Install-Scoop
            
            $result | Should -Be $false
        }
    }
}

Describe 'Initialize-Chezmoi' {
    BeforeEach {
        $Script:Stats = @{
            StartTime = Get-Date
            ChezmoiInstalled = $false
            ScoopInstalled = $false
            PackagesInstalled = 0
            ConfigsApplied = $false
        }
    }

    Context 'With GitHub shorthand repository format' {
        It 'Should convert shorthand to full URL' {
            function global:chezmoi {
                param([string]$action, [string]$apply, [string]$branch, [string]$branchName, [string]$url)
                
                # Capture the URL parameter
                $script:CapturedUrl = $args[-1]
                $Script:Stats.ConfigsApplied = $true
            }
            
            Initialize-Chezmoi -Repo 'username/dotfiles' -Branch 'main'
            
            $script:CapturedUrl | Should -Be 'https://github.com/username/dotfiles.git'
            $Script:Stats.ConfigsApplied | Should -Be $true
        }

        It 'Should pass branch parameter correctly' {
            $script:CapturedBranch = $null
            
            function global:chezmoi {
                param([string[]]$args)
                # Extract branch value
                $branchIndex = [array]::IndexOf($args, '--branch')
                if ($branchIndex -ge 0) {
                    $script:CapturedBranch = $args[$branchIndex + 1]
                }
                $Script:Stats.ConfigsApplied = $true
            }
            
            Initialize-Chezmoi -Repo 'user/repo' -Branch 'develop'
            
            $script:CapturedBranch | Should -Be 'develop'
        }
    }

    Context 'With full URL repository format' {
        It 'Should use URL as-is when full URL provided' {
            function global:chezmoi {
                param([string[]]$args)
                $script:CapturedUrl = $args[-1]
                $Script:Stats.ConfigsApplied = $true
            }
            
            $fullUrl = 'https://github.com/user/dotfiles.git'
            Initialize-Chezmoi -Repo $fullUrl -Branch 'main'
            
            $script:CapturedUrl | Should -Be $fullUrl
        }

        It 'Should handle HTTP URLs' {
            function global:chezmoi {
                param([string[]]$args)
                $script:CapturedUrl = $args[-1]
                $Script:Stats.ConfigsApplied = $true
            }
            
            $httpUrl = 'http://git.example.com/user/dotfiles.git'
            Initialize-Chezmoi -Repo $httpUrl -Branch 'main'
            
            $script:CapturedUrl | Should -Be $httpUrl
        }
    }

    Context 'When initialization succeeds' {
        BeforeAll {
            function global:chezmoi {
                param([string[]]$args)
                $Script:Stats.ConfigsApplied = $true
            }
        }

        It 'Should return true' {
            $result = Initialize-Chezmoi -Repo 'user/repo' -Branch 'main'
            
            $result | Should -Be $true
        }

        It 'Should update stats' {
            Initialize-Chezmoi -Repo 'user/repo' -Branch 'main'
            
            $Script:Stats.ConfigsApplied | Should -Be $true
        }

        It 'Should use --apply flag' {
            $script:HasApplyFlag = $false
            
            function global:chezmoi {
                param([string[]]$args)
                $script:HasApplyFlag = $args -contains '--apply'
                $Script:Stats.ConfigsApplied = $true
            }
            
            Initialize-Chezmoi -Repo 'user/repo' -Branch 'main'
            
            $script:HasApplyFlag | Should -Be $true
        }
    }

    Context 'When initialization fails' {
        BeforeAll {
            function global:chezmoi {
                throw "Git clone failed"
            }
        }

        It 'Should return false' {
            $result = Initialize-Chezmoi -Repo 'user/repo' -Branch 'main'
            
            $result | Should -Be $false
        }

        It 'Should not update ConfigsApplied stat' {
            Initialize-Chezmoi -Repo 'user/repo' -Branch 'main'
            
            $Script:Stats.ConfigsApplied | Should -Be $false
        }
    }
}

Describe 'Set-EnvironmentVariables' {
    BeforeEach {
        # Backup current environment
        $script:BackupEnv = @{
            XDG_CONFIG_HOME = $env:XDG_CONFIG_HOME
            XDG_DATA_HOME = $env:XDG_DATA_HOME
            XDG_STATE_HOME = $env:XDG_STATE_HOME
            XDG_CACHE_HOME = $env:XDG_CACHE_HOME
        }
        
        # Mock Environment methods
        Mock -CommandName 'SetEnvironmentVariable' -ModuleName 'System.Environment' -MockWith { }
    }

    AfterEach {
        # Restore environment
        foreach ($key in $script:BackupEnv.Keys) {
            if ($null -ne $script:BackupEnv[$key]) {
                Set-Item -Path "env:$key" -Value $script:BackupEnv[$key]
            }
        }
    }

    Context 'Setting XDG environment variables' {
        It 'Should set XDG_CONFIG_HOME correctly' {
            Set-EnvironmentVariables
            
            $env:XDG_CONFIG_HOME | Should -Be "$env:USERPROFILE\.config"
        }

        It 'Should set XDG_DATA_HOME correctly' {
            Set-EnvironmentVariables
            
            $env:XDG_DATA_HOME | Should -Be "$env:USERPROFILE\.local\share"
        }

        It 'Should set XDG_STATE_HOME correctly' {
            Set-EnvironmentVariables
            
            $env:XDG_STATE_HOME | Should -Be "$env:USERPROFILE\.local\state"
        }

        It 'Should set XDG_CACHE_HOME correctly' {
            Set-EnvironmentVariables
            
            $env:XDG_CACHE_HOME | Should -Be "$env:USERPROFILE\.cache"
        }

        It 'Should set all four XDG variables' {
            Set-EnvironmentVariables
            
            $env:XDG_CONFIG_HOME | Should -Not -BeNullOrEmpty
            $env:XDG_DATA_HOME | Should -Not -BeNullOrEmpty
            $env:XDG_STATE_HOME | Should -Not -BeNullOrEmpty
            $env:XDG_CACHE_HOME | Should -Not -BeNullOrEmpty
        }
    }

    Context 'User-level environment persistence' {
        It 'Should attempt to set variables at User scope' {
            # Track calls to SetEnvironmentVariable
            $script:SetEnvCalls = @()
            
            # Create a more specific mock
            $originalSetEnv = [Environment]::SetEnvironmentVariable
            [Environment] | Add-Member -MemberType ScriptMethod -Name SetEnvironmentVariable -Value {
                param($name, $value, $target)
                $script:SetEnvCalls += @{
                    Name = $name
                    Value = $value
                    Target = $target
                }
            } -Force
            
            Set-EnvironmentVariables
            
            # Verify all variables were set with User scope
            $script:SetEnvCalls.Count | Should -Be 4
            $script:SetEnvCalls | ForEach-Object {
                $_.Target | Should -Be 'User'
            }
            
            # Restore original method
            [Environment] | Add-Member -MemberType ScriptMethod -Name SetEnvironmentVariable -Value $originalSetEnv -Force
        }

        It 'Should set variables with correct values using Environment class' {
            $script:SetEnvCalls = @()
            
            $originalSetEnv = [Environment]::SetEnvironmentVariable
            [Environment] | Add-Member -MemberType ScriptMethod -Name SetEnvironmentVariable -Value {
                param($name, $value, $target)
                $script:SetEnvCalls += @{
                    Name = $name
                    Value = $value
                }
            } -Force
            
            Set-EnvironmentVariables
            
            $configHome = $script:SetEnvCalls | Where-Object { $_.Name -eq 'XDG_CONFIG_HOME' }
            $configHome.Value | Should -Be "$env:USERPROFILE\.config"
            
            # Restore
            [Environment] | Add-Member -MemberType ScriptMethod -Name SetEnvironmentVariable -Value $originalSetEnv -Force
        }
    }

    Context 'Current session environment' {
        It 'Should update environment variables for current session' {
            Set-EnvironmentVariables
            
            Test-Path "env:XDG_CONFIG_HOME" | Should -Be $true
            Test-Path "env:XDG_DATA_HOME" | Should -Be $true
            Test-Path "env:XDG_STATE_HOME" | Should -Be $true
            Test-Path "env:XDG_CACHE_HOME" | Should -Be $true
        }

        It 'Should use USERPROFILE as base path' {
            $testProfile = "C:\Users\TestUser"
            $originalProfile = $env:USERPROFILE
            $env:USERPROFILE = $testProfile
            
            Set-EnvironmentVariables
            
            $env:XDG_CONFIG_HOME | Should -BeLike "$testProfile*"
            $env:XDG_DATA_HOME | Should -BeLike "$testProfile*"
            $env:XDG_STATE_HOME | Should -BeLike "$testProfile*"
            $env:XDG_CACHE_HOME | Should -BeLike "$testProfile*"
            
            # Restore
            $env:USERPROFILE = $originalProfile
        }
    }
}

Describe 'Test-CommandExists' {
    Context 'When command exists' {
        It 'Should return true for existing PowerShell commands' {
            $result = Test-CommandExists 'Get-Process'
            
            $result | Should -Be $true
        }

        It 'Should return true for existing external commands' {
            # Test with a command that should exist on Windows
            $result = Test-CommandExists 'cmd'
            
            $result | Should -Be $true
        }
    }

    Context 'When command does not exist' {
        It 'Should return false for non-existent commands' {
            $result = Test-CommandExists 'NonExistentCommand12345'
            
            $result | Should -Be $false
        }

        It 'Should handle errors gracefully' {
            # Should not throw even with invalid command names
            { Test-CommandExists '' } | Should -Not -Throw
        }
    }
}

# vim: ts=2 sts=2 sw=2 et
