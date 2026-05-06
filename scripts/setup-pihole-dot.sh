#!/usr/bin/env bash
# ============================================================================
# Pi-side DoT terminator setup
# ============================================================================
# RUN THIS ON THE PI, NOT ON THE MAC.
#
# Stands up unbound on :853 doing DoT, forwarding plain DNS to Pi-hole at
# 127.0.0.1:53. Uses a TLS cert minted by `tailscale cert` so the macOS
# Encrypted DNS profile (managed by this dotfiles repo's encrypted_dns
# block) can connect with hostname verification.
#
# Layout after this script runs:
#   :853 (TLS, exposed)  -> unbound -> 127.0.0.1:53 (Pi-hole, plaintext-local)
#
# Idempotent: re-running upgrades configs and reloads unbound. Cert refresh
# should be wired up via cron / systemd timer separately (Tailscale certs
# expire after 90 days).
#
# Usage:
#   scp ~/projects/personal/dotfiles/scripts/setup-pihole-dot.sh raspi:/tmp/
#   ssh raspi 'sudo bash /tmp/setup-pihole-dot.sh'
# ============================================================================

set -euo pipefail

HOSTNAME_FQDN="${HOSTNAME_FQDN:-raspi.tailf7fd34.ts.net}"
UPSTREAM_HOST="${UPSTREAM_HOST:-127.0.0.1}"
UPSTREAM_PORT="${UPSTREAM_PORT:-53}"   # Pi-hole's listening port (dnsmasq)
DOT_PORT="${DOT_PORT:-853}"
CERT_DIR="${CERT_DIR:-/etc/unbound/tls}"
UNBOUND_CONF="/etc/unbound/unbound.conf.d/99-pihole-dot.conf"

log() { printf '[setup-pihole-dot] %s\n' "$*"; }
err() { printf '[setup-pihole-dot] ERROR: %s\n' "$*" >&2; exit 1; }

[ "$EUID" -eq 0 ] || err "must run as root (sudo)"

# ---------------------------------------------------------------------------
# 1. Install unbound (skip if already present).
# ---------------------------------------------------------------------------
if ! command -v unbound >/dev/null 2>&1; then
    log "installing unbound"
    apt-get update -qq
    apt-get install -y unbound
else
    log "unbound already installed"
fi

# ---------------------------------------------------------------------------
# 2. Mint / renew TLS cert via Tailscale.
# ---------------------------------------------------------------------------
if ! command -v tailscale >/dev/null 2>&1; then
    err "tailscale CLI not found; install/join the tailnet first"
fi

mkdir -p "$CERT_DIR"
chown unbound:unbound "$CERT_DIR" 2>/dev/null || true
chmod 0750 "$CERT_DIR"

CERT_FILE="${CERT_DIR}/${HOSTNAME_FQDN}.crt"
KEY_FILE="${CERT_DIR}/${HOSTNAME_FQDN}.key"

log "minting tailscale cert for $HOSTNAME_FQDN (requires HTTPS feature enabled in admin console)"
pushd "$CERT_DIR" >/dev/null
tailscale cert "$HOSTNAME_FQDN"
popd >/dev/null

[ -s "$CERT_FILE" ] || err "cert file not found at $CERT_FILE"
[ -s "$KEY_FILE"  ] || err "key file not found at $KEY_FILE"

chown unbound:unbound "$CERT_FILE" "$KEY_FILE"
chmod 0640 "$KEY_FILE"
chmod 0644 "$CERT_FILE"

# ---------------------------------------------------------------------------
# 3. Drop in unbound config for DoT terminator.
# ---------------------------------------------------------------------------
log "writing $UNBOUND_CONF"
cat > "$UNBOUND_CONF" <<EOF
# Managed by setup-pihole-dot.sh -- do not edit by hand.
#
# unbound here is purely a DoT terminator that forwards plain DNS to
# Pi-hole on 127.0.0.1:53. We don't recurse and we don't validate --
# Pi-hole + upstream resolver handle that. Disabling the validator
# avoids the auto-trust-anchor / root.key bootstrap dance entirely.
server:
    interface: 0.0.0.0@${DOT_PORT}
    interface: ::0@${DOT_PORT}
    tls-service-key: "${KEY_FILE}"
    tls-service-pem: "${CERT_FILE}"
    tls-port: ${DOT_PORT}
    # No DNSSEC validation in unbound itself (we're not recursive).
    module-config: "iterator"
    # Default is yes; we MUST allow it because Pi-hole listens on 127.0.0.1.
    do-not-query-localhost: no
    # Accept queries from loopback, LAN, and the tailnet only.
    access-control: 127.0.0.0/8 allow
    access-control: 192.168.0.0/16 allow
    access-control: 10.0.0.0/8 allow
    access-control: 100.64.0.0/10 allow
    access-control: fd7a:115c:a1e0::/48 allow
    do-tcp: yes
    do-udp: no
    use-caps-for-id: no
    prefetch: yes

forward-zone:
    name: "."
    forward-addr: ${UPSTREAM_HOST}@${UPSTREAM_PORT}
EOF

# ---------------------------------------------------------------------------
# 4. Validate and reload.
# ---------------------------------------------------------------------------
log "validating config"
unbound-checkconf >/dev/null

log "enabling and (re)starting unbound"
systemctl enable unbound >/dev/null 2>&1 || true
systemctl restart unbound

# ---------------------------------------------------------------------------
# 5. Smoke test from localhost.
# ---------------------------------------------------------------------------
log "smoke testing DoT on :${DOT_PORT}"
sleep 1
if command -v kdig >/dev/null 2>&1; then
    # Hit the public hostname so the cert chain (Let's Encrypt) verifies
    # against the system CA bundle. 127.0.0.1 would fail SNI hostname check.
    kdig @"$HOSTNAME_FQDN" +tls +short example.com \
        || err "kdig DoT query failed"
elif command -v openssl >/dev/null 2>&1; then
    # Use the system trust store (Let's Encrypt roots), not the leaf cert.
    if ! echo | openssl s_client -connect "${HOSTNAME_FQDN}:${DOT_PORT}" \
            -servername "$HOSTNAME_FQDN" -verify_return_error \
            </dev/null >/dev/null 2>&1; then
        err "openssl s_client handshake failed"
    fi
    log "TLS handshake OK (DNS query test requires kdig/knot-dnsutils)"
else
    log "neither kdig nor openssl found; skipping smoke test"
fi

log "done. macOS profile in dotfiles will pick this up on next 'chezmoi apply'."
log "Reminder: tailscale certs expire after 90 days. Schedule a renew, e.g.:"
log "  echo '0 3 * * 1 root bash /usr/local/sbin/setup-pihole-dot.sh' > /etc/cron.d/pihole-dot-renew"
