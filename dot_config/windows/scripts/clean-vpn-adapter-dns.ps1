<#
.SYNOPSIS
    Strip everything except 127.0.0.1 from VPN tunnel adapter IPv4 DNS lists.

.DESCRIPTION
    Run by a Scheduled Task (installed by
    .chezmoiscripts/run_onchange_after_59_vpn-dns-watcher_windows.ps1.tmpl)
    whenever a known VPN tunnel service enters the "running" state — currently
    just `ProtonVPN WireGuard`. When Proton's WireGuard tunnel comes up it
    attaches `10.2.0.1` to its adapter, which Windows happily queries in
    parallel with the loopback unbound resolver. The in-tunnel resolver is
    lower latency than `127.0.0.1 -> DoT -> raspi`, so 10.2.0.1 wins the race
    most of the time and DNS leaks to Proton's resolver. NRPT catch-all rules
    do NOT override per-adapter DNS in this case because Proton's rule
    contributes no nameservers and Windows still consults the adapter list.

    Solution: every time a VPN tunnel adapter (re)appears, force its IPv4 DNS
    to exactly [127.0.0.1]. NRPT then routes via loopback -> local unbound ->
    DoT to raspi -> Pi-hole -> dnscrypt-proxy (encrypted upstream).

    Tailscale is intentionally NOT in this list: its NRPT catch-all is how
    MagicDNS resolves .ts.net and short tailnet hostnames; clobbering its
    adapter DNS would break that path.

.NOTES
    Deployed by chezmoi to: ~/.config/windows/scripts/clean-vpn-adapter-dns.ps1
    Scheduled task runs as SYSTEM, so this script assumes elevated context.
    Idempotent: no-op when adapter is down or DNS is already [127.0.0.1].
#>
[CmdletBinding()]
param(
    # VPN tunnel adapter alias patterns to clean. Each entry is a regex
    # matched against InterfaceAlias (anchored implicitly via -match).
    # ProtonVPN names its adapter differently per protocol:
    #   - `ProtonVPN`      when in WireGuard mode (injects `10.2.0.1`)
    #   - `ProtonVPN TUN`  when in OpenVPN/TUN mode (injects `10.96.0.1`)
    # The user toggles between these in the Proton client, so we have to
    # match both. `^ProtonVPN( TUN)?$` covers both exactly without
    # accidentally matching something like `ProtonVPN-Test`.
    #
    # Pritunl is intentionally NOT in this list. Verified 2026-05-13:
    #   - Adapter name is `pritunl0` (lowercase + digit suffix that can
    #     change), not `Pritunl`.
    #   - Its adapter DNS list is empty when connected -- Pritunl does not
    #     inject a DNS server onto its tunnel adapter the way Proton does.
    #   - Pritunl installs its own NRPT rule (`.dreamhost.com` -> 10.25.0.15,
    #     comment 'DH VPN') for split-DNS, which is the right mechanism
    #     and doesn't conflict with our catch-all to 127.0.0.1.
    # So there's nothing to clean on Pritunl reconnect.
    [string[]]$AdapterPatterns = @('^ProtonVPN( TUN)?$'),

    # Target DNS list to enforce. Single entry = our local unbound.
    [string[]]$TargetDns = @('127.0.0.1'),

    # Optional log path. The scheduled task writes here so we can debug
    # without attaching to the running task.
    [string]$LogPath = "$env:ProgramData\chezmoi\clean-vpn-adapter-dns.log",

    # Brief settle delay before reading adapter state. The 7036 "running"
    # event fires the instant the service registers; the WireGuard adapter
    # and its DNS list usually appear a few hundred ms later.
    [int]$SettleMs = 750
)

$ErrorActionPreference = 'Stop'

# Ensure log dir exists and rotate if too big (>1MB).
$logDir = Split-Path -Parent $LogPath
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}
if ((Test-Path $LogPath) -and ((Get-Item $LogPath).Length -gt 1MB)) {
    Move-Item -Path $LogPath -Destination "$LogPath.old" -Force
}

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'
    "$ts [$Level] $Message" | Add-Content -LiteralPath $LogPath -Encoding utf8
}

Write-Log "started; patterns=[$($AdapterPatterns -join ', ')] target=[$($TargetDns -join ', ')]"

Start-Sleep -Milliseconds $SettleMs

# Resolve patterns -> actual adapter aliases that exist and are Up.
$matchedAdapters = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object {
    $alias = $_.InterfaceAlias
    $AdapterPatterns | Where-Object { $alias -match $_ }
}

if (-not $matchedAdapters) {
    Write-Log "no adapters matched any pattern; nothing to do"
    Write-Log "done; changed=0"
    return
}

$changed = 0
foreach ($adapter in $matchedAdapters) {
    $alias = $adapter.InterfaceAlias
    try {
        if ($adapter.Status -ne 'Up') {
            Write-Log "skip: adapter '$alias' status=$($adapter.Status)"
            continue
        }

        $current = (Get-DnsClientServerAddress -InterfaceAlias $alias -AddressFamily IPv4 -ErrorAction SilentlyContinue).ServerAddresses
        $currentStr = if ($current) { $current -join ',' } else { '(empty)' }

        # Idempotent: only touch if list isn't already exactly our target.
        $needsChange = $false
        if (-not $current -or $current.Count -ne $TargetDns.Count) {
            $needsChange = $true
        } else {
            for ($i = 0; $i -lt $TargetDns.Count; $i++) {
                if ($current[$i] -ne $TargetDns[$i]) { $needsChange = $true; break }
            }
        }

        if (-not $needsChange) {
            Write-Log "ok: '$alias' already [$currentStr]"
            continue
        }

        Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses $TargetDns
        Write-Log "set: '$alias' DNS [$currentStr] -> [$($TargetDns -join ',')]"
        $changed++
    } catch {
        Write-Log "fail: '$alias' $($_.Exception.Message)" 'ERROR'
    }
}

if ($changed -gt 0) {
    try {
        ipconfig /flushdns | Out-Null
        Write-Log "flushed resolver cache after $changed adapter change(s)"
    } catch {
        Write-Log "flushdns failed: $($_.Exception.Message)" 'WARN'
    }
}

Write-Log "done; changed=$changed"
