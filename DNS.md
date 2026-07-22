# DNS Architecture

How DNS resolution actually works on this stack, and where each piece lives in the chezmoi source tree. Last verified `2026-05-13`.
## Platform variants
- **macOS** uses the resolver chain described below (Tailscale MagicDNS -> Pi-hole over the tailnet, with `/etc/resolver` split-DNS for work domains).
- **Windows** uses a different first hop: a local `unbound` Windows service on `127.0.0.1:53` (managed by `.chezmoiscripts/run_onchange_after_56_unbound_windows.ps1.tmpl`) that forwards via DoT to the raspi terminator on `:853`. Physical adapters and the ProtonVPN tunnel adapter (Tailscale and Pritunl excepted) get their per-adapter DNS pinned to `127.0.0.1`, and a Scheduled Task re-pins ProtonVPN's tunnel adapter on every reconnect, so DNS doesn't leak to VPN-injected adapter DNS lists (Proton's `<proton-vpn-dns-ip>` is the motivating case). NRPT is used **only** for Pritunl VPN-internal split-DNS, not a localhost catch-all — a `.`→`127.0.0.1` catch-all was removed as unsafe (a stalled local resolver would break all name resolution). See the Windows section below.
## TL;DR

```text
Mac apps ──► macOS mDNSResponder ──► tailnet (100.x.x.x) over WireGuard
                                          │
                          ┌───────────────┴───────────────┐
                          ▼                               ▼
              <tailscale-magicdns-ip> (Tailscale          <pi-tailnet-ip> (Pi-hole on Pi,
              MagicDNS proxy)                      direct tailnet route)
                          │                               │
                          └────► forwards to ─────────────┘
                                                          │
                                                          ▼
                                          Pi-hole (dnsmasq) :53 on raspi
                                                          │
                                                ┌─────────┴─────────┐
                                                ▼                   ▼
                                         filter / log      forward upstream
                                                                    │
                                                                    ▼
                                          (whatever Pi-hole forwards to: DoT/DoH
                                           upstream — Cloudflare/Quad9/cloudflared)
```

Important properties:

- All DNS queries traverse the WireGuard tunnel (CGNAT 100.x.x.x). Nothing leaves the Mac in plaintext UDP/53.
- Pi-hole sees every query → blocklists / logs apply system-wide, including from browsers (DoH disabled).
- Browsers use the system resolver; no per-browser DoH bypass.
- A DoT (`com.apple.dnsSettings.managed`) profile is installed as a fallback path for off-tailnet scenarios.

## Resolver hierarchy on the Mac

`scutil --dns` reports several supplemental + scoped resolvers. The relevant ones, in priority order:

1. **Tailscale MagicDNS** (`utun9`) — `<tailscale-magicdns-ip>` / `fd7a:115c:a1e0::53`. Tailscale injects this at the per-interface level via NetworkExtension, which **outranks** system-scope profile DNS in macOS. This is why the encrypted DNS profile we install is not resolver #1 (see below).
2. **Direct tailnet route to Pi-hole** — `<pi-tailnet-ip>`. macOS may parallel-query this and MagicDNS for the same name; both responses are equivalent because MagicDNS forwards there anyway.
3. **Split-DNS for work domains** — `/etc/resolver/<domain>` files routing `dh-int.com`, `dreamhost.*`, etc. to `<vpn-dns-ip>` (Pritunl-internal DNS). Only used when those domains are queried; only resolves when Pritunl is up.
4. **Encrypted DNS profile (DoT, fallback)** — `raspi.<your-tailnet>.ts.net` over TLS to `<pi-tailnet-ip>:853`. Installed but generally not the active resolver because Tailscale outranks it. Becomes primary when Tailscale is down or `accept-dns` is off.
5. **LAN fallback** — `<router-ip>` (router). Last-resort. Plaintext UDP/53. Not used in current observed behavior.

## Components and where they live

### Pi side (raspi.<your-tailnet>.ts.net)

- **Pi-hole** (dnsmasq) on `:53/udp,tcp`, listening on LAN + tailscale interfaces. Filters and logs.
- **unbound** as a DoT terminator on `:853/tcp`. TLS cert from `tailscale cert`. Forwards plain DNS to `127.0.0.1:53` (Pi-hole). `module-config: "iterator"` (no validator — Pi-hole's upstream handles DNSSEC).
- Both are managed by `scripts/setup-pihole-dot.sh` (the DoT bit) and Pi-hole's own setup (separate).

### Mac side (chezmoi-managed)

| Concern | File | Triggered by |
| --- | --- | --- |
| Encrypted DNS profile data | `.chezmoidata/dns.yaml` → `encrypted_dns` block (resolver host + addresses come from `.infra.pi_fqdn` / `.infra.dns_pi_addrs`) | data hash change |
| `.mobileconfig` source | `dot_config/dns/private_pihole-dot.mobileconfig.tmpl` | `chezmoi apply` |
| Profile install/refresh | `.chezmoiscripts/run_onchange_after_56_encrypted-dns.sh.tmpl` | data hash change |
| Browser DoH disable data | `.chezmoidata/dns.yaml` → `browser_doh` block | data hash change |
| Browser policies install | `.chezmoiscripts/run_onchange_after_57_browser-doh-policies.sh.tmpl` | data hash change |
| VPN split-DNS data | `.chezmoi.local.toml` `[data.infra]` → `vpn_pritunl_ns` + `vpn_pritunl_domains` (gitignored; formerly the `vpn_dns_routes` block in `.chezmoidata/dns.yaml`) | data hash change |
| VPN split-DNS install | `.chezmoiscripts/run_onchange_after_55_vpn-dns-routes.sh.tmpl` | data hash change |
| Pi-side DoT setup | `scripts/setup-pihole-dot.sh` | manual run on the Pi |

### Browser DoH disable mechanics

- **Firefox** — `/Library/Application Support/Mozilla/policies/policies.json` with `DNSOverHTTPS.Enabled=false, Locked=true`. Mozilla enterprise policy — no MDM required.
- **Chrome / Edge / Brave** — `defaults write com.google.Chrome DnsOverHttpsMode -string "off"` (etc.) to user CFPreferences (`~/Library/Preferences/<bundle>.plist`). Chromium reads these on launch. Note: this is a "preference" not an MDM-forced "policy"; on a single-user machine the distinction is irrelevant. `/Library/Managed Preferences/` would require MDM enrollment to write.

## Why the DoT profile is not resolver #1

Apple's resolver priority is roughly:

1. Per-interface DNS (NetworkExtension installs from VPN / Tailscale).
2. Profile DNS (`com.apple.dnsSettings.managed`).
3. Network service DNS (set per Wi-Fi / Ethernet service).
4. mDNS / link-local.

Tailscale runs as a NetworkExtension so its DNS is at level 1. Our DoT profile is at level 2. Apple does not provide a documented way to flip this without disabling Tailscale's `accept-dns`.

This is **not a problem** for the security goal (encrypted LAN-leg DNS) because:

- The Tailscale resolver IPs (`<tailscale-magicdns-ip>`, `<pi-tailnet-ip>`) are inside the WireGuard tunnel — packets to them are already encrypted.
- The DoT profile remains a valid fallback when Tailscale is off (or you're on a machine with `accept-dns=false`).

If you ever want DoT to be primary:

```sh
tailscale set --accept-dns=false
```

You will lose Tailscale's split-DNS for `*.ts.net` and `raspi.homelab` until you re-enable it.

## Verification commands

```sh
# Active resolvers and their nameservers (look for "dns over tls" annotation)
scutil --dns

# Confirm the DoT profile is installed
sudo profiles list -type configuration | grep pihole-dot

# End-to-end DoT query against the Pi
kdig @raspi.<your-tailnet>.ts.net +tls +short example.com

# Reflective probe — what the world sees as your resolver's egress IP
dig +short TXT o-o.myaddr.l.google.com @ns1.google.com

# Brief leak capture: every DNS packet should be on the 100.x tailnet
sudo timeout 5 tcpdump -nn -i any 'udp port 53 or tcp port 53 or tcp port 853'

# Browser DoH state
cat "/Library/Application Support/Mozilla/policies/policies.json"
defaults read com.google.Chrome DnsOverHttpsMode      # off
defaults read com.microsoft.Edge DnsOverHttpsMode     # off
defaults read com.brave.Browser  DnsOverHttpsMode     # off

# Pi-side health
ssh raspi 'sudo systemctl is-active unbound; sudo ss -ltnp | grep :853'
ssh raspi 'sudo unbound-control status'
```

## Operational notes

- **Tailscale `cert` renewal**: certs minted by `tailscale cert` expire after 90 days. The Pi-side helper script is idempotent — re-run it (manually or via cron) to renew. Schedule:
  ```sh
  echo '0 3 * * 1 root bash /usr/local/sbin/setup-pihole-dot.sh' | sudo tee /etc/cron.d/pihole-dot-renew
  ```
- **Approving the DoT profile after install**: macOS no longer auto-installs unsigned profiles. The `run_onchange_after_56_encrypted-dns.sh` script `open`s the `.mobileconfig` so System Settings prompts for approval. You only need to do this once per fresh machine; subsequent `chezmoi apply` runs no-op when the profile is already installed.
- **Pi outage behavior**: if the Pi is unreachable (Tailscale down, raspi off), DNS resolution will lag and then fall back to whatever's last in the resolver chain (currently `<router-ip>` if it's still configured on the Wi-Fi service). To make Pi outages fail loudly instead of degrading silently, drop the LAN fallback nameservers from the active network service:
  ```sh
  networksetup -setdnsservers "Wi-Fi" empty
  ```
- **Adding a new VPN's split-DNS**: set `vpn_pritunl_ns` / `vpn_pritunl_domains` under `[data.infra]` in `.chezmoi.local.toml` and `chezmoi apply`. The `run_onchange_after_55` script reconciles `/etc/resolver/<domain>` files.
## Windows variant
The Windows hop chain is intentionally different because Windows lacks `/etc/resolver` and because VPN adapters there (Proton, Pritunl) attach their own DNS to their tunnel interfaces, which Windows happily uses over the loopback resolver. Layout:
```text
Windows app
  | (per-adapter DNS pinned to 127.0.0.1; NRPT only for Pritunl split-DNS)
  v
127.0.0.1:53  -- unbound service (no recursion, DoT forward-only)
  | DoT (TCP/853 + TLS)
  v
  forward-addr: <pi-lan-ip>@853#raspi.<your-tailnet>.ts.net   (LAN, preferred)
  forward-addr: <pi-tailnet-ip>@853#raspi.<your-tailnet>.ts.net (tailnet fallback)
  | TLS, validated against scoop cacert bundle
  v
raspi:853  -- unbound DoT terminator (iterator only, no validator)
  v
127.0.0.1:53 on raspi  -- Pi-hole (dnsmasq, filter + log)
  v
dnscrypt-proxy:5053  -- DoH/DNSCrypt outbound (encrypted upstream to Cloudflare/Quad9/etc.)
```
Key pieces:
| Concern | File | Notes |
| --- | --- | --- |
| Local unbound install/refresh | `.chezmoiscripts/run_onchange_after_56_unbound_windows.ps1.tmpl` | Installs scoop `unbound` as a Windows service; sets adapter DNS to `127.0.0.1` only after the listener responds. |
| unbound config | `unbound/service.conf.tmpl` | Forwarder mode, no recursion, no validator, no public DoT fallback. |
| Per-adapter DNS pin (Proton override) | `.chezmoiscripts/run_onchange_after_56_unbound_windows.ps1.tmpl` | Pins physical adapters and the ProtonVPN tunnel adapter to `127.0.0.1` once the local cache is verified responsive. Tailscale is excepted (so MagicDNS keeps working); so is Pritunl (its adapter DNS is empty — it uses NRPT split-DNS instead). Replaces the old `.`→`127.0.0.1` NRPT catch-all, removed as unsafe: if the local resolver stalls, a catch-all breaks *all* name resolution. Proton's WireGuard tunnel attaches `<proton-vpn-dns-ip>`; pinning its adapter to loopback stops that from winning the race. Live re-pinning on reconnect: see the auto-cleanup row below. |
| NRPT VPN-internal routes | same script, `.infra.vpn_pritunl_ns` + `.infra.vpn_pritunl_domains` | One NRPT rule per internal work domain routes it to the Pritunl resolver (`<vpn-dns-ip>`); everything else follows the per-adapter DNS pin (loopback), since there is no `.` catch-all rule. |
| Proton split-tunnel allow-list | Proton GUI -> Settings -> Split Tunneling -> Bypass VPN | Must include `100.64.0.0/10` and `fd7a:115c:a1e0::/48` so unbound's tailnet fallback (`<pi-tailnet-ip>@853`) is reachable when off-LAN. Without this Proton's kill switch drops all Tailscale traffic, including DNS. |
| VPN tunnel adapter DNS auto-cleanup | `.chezmoiscripts/run_onchange_after_59_vpn-dns-watcher_windows.ps1.tmpl` + `dot_config/windows/scripts/clean-vpn-adapter-dns.ps1` | Registers a Scheduled Task triggered by System log event 7036 (Service Control Manager: `ProtonVPN WireGuard` -> `running`). Runs the cleanup script as SYSTEM, which strips everything except `127.0.0.1` from VPN tunnel adapter DNS. Without this, Proton's WireGuard tunnel re-injects `<proton-vpn-dns-ip>` on every reconnect (sleep/wake, server hop, kill-switch toggle) and DNS leaks until the next `chezmoi apply`. Logs to `%ProgramData%\chezmoi\clean-vpn-adapter-dns.log`. |
Verification (Windows):
```pwsh
# Every active adapter's IPv4 DNS should be pinned to 127.0.0.1 (there is no '.' NRPT catch-all)
Get-DnsClientServerAddress -AddressFamily IPv4 | Select-Object InterfaceAlias, ServerAddresses
# o-o.myaddr.l.google.com TXT should return dnscrypt-proxy's upstream
# (Cloudflare, 172.x), NOT Proton's exit (159.26.x).
(Resolve-DnsName -Name 'o-o.myaddr.l.google.com' -Type TXT -QuickTimeout).Strings
# Egress IP test - should be Proton's exit when Proton is on.
curl.exe -s https://api.ipify.org
# Confirm Pi-hole sees queries (run on raspi):
#   docker exec pihole tail -f /var/log/pihole/pihole.log
```
## Past failure modes (so we don't repeat them)

- `unbound` defaulted to `module-config: "validator iterator"` and `do-not-query-localhost: yes`. The first needed `auto-trust-anchor-file` (`/var/lib/unbound/root.key`) seeded; the second blocks forwarding to `127.0.0.1:53`. Fixed by setting `module-config: "iterator"` and `do-not-query-localhost: no` in the unbound config — unbound here is a pure DoT terminator/forwarder, not a recursive resolver.
- `profiles install -path ...` was removed in modern macOS — even with sudo it errors out with *"profiles tool no longer supports installs."* The script now stages the file with `open`, which surfaces it in System Settings for one-click install.
- `defaults write /Library/Managed\ Preferences/<bundle>` is a silent no-op without MDM enrollment. The script writes Chromium policy keys to user CFPreferences instead.
- The original chezmoi template for `~/.ssh/raspi.pub` referenced `op://Personal/...` but the SSH key actually lived in the `Homelab` 1Password vault, so the `.pub` rendered empty and `ssh raspi` failed `Permission denied (publickey)`. Fixed by repointing the template at the correct vault and item ID.
