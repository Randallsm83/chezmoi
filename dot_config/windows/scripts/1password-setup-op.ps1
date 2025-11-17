#!/usr/bin/env pwsh
# 1Password CLI Setup Script
# This script helps configure the 1Password CLI (op) with your account

#Requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

function Write-Status {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string]$Type = 'Info'
    )
    
    $colors = @{
        Info    = 'Cyan'
        Success = 'Green'
        Warning = 'Yellow'
        Error   = 'Red'
    }
    
    Write-Host $Message -ForegroundColor $colors[$Type]
}

# Check if op is installed
if (-not (Get-Command op -ErrorAction SilentlyContinue)) {
    Write-Status "1Password CLI (op) not found!" -Type Error
    Write-Status "Install it via mise: mise install op" -Type Info
    exit 1
}

Write-Host @"

========================================
1Password CLI Setup
========================================

This script will help you configure the 1Password CLI.

You'll need:
  1. Your 1Password account address (e.g., my.1password.com)
  2. Your email address
  3. Your Secret Key (from Emergency Kit)
  4. Your Master Password

"@ -ForegroundColor Cyan

# Prompt for account details
$address = Read-Host "1Password account address (default: my.1password.com)"
if ([string]::IsNullOrWhiteSpace($address)) {
    $address = "my.1password.com"
}

$email = Read-Host "Email address"
if ([string]::IsNullOrWhiteSpace($email)) {
    Write-Status "Email is required!" -Type Error
    exit 1
}

Write-Host @"

Running: op account add --address $address --email $email

You will be prompted for:
  1. Secret Key (format: A3-XXXXXX-XXXXXX-XXXXX-XXXXX-XXXXX-XXXXX)
  2. Master Password

"@ -ForegroundColor Yellow

# Run the account add command
try {
    op account add --address $address --email $email
    
    if ($LASTEXITCODE -eq 0) {
        Write-Status "`nAccount added successfully!" -Type Success
        Write-Status "`nTo sign in, run: op signin" -Type Info
        Write-Status "Or use PowerShell: Invoke-Expression `$(op signin)" -Type Info
    } else {
        Write-Status "`nFailed to add account. Exit code: $LASTEXITCODE" -Type Error
        exit $LASTEXITCODE
    }
} catch {
    Write-Status "Error: $_" -Type Error
    exit 1
}
