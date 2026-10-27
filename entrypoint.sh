#!/bin/bash
# Runs adguardvpn-cli in TUN mode and keeps it alive. Containers that share
# this network namespace (network_mode: service:...) must never lose it, so
# this script never exits because of VPN trouble: it reconnects in place.
set -euo pipefail

: "${VPN_LOCATION:=DE}"        # city, country or ISO code
: "${VPN_PROBE_INTERVAL:=30}"  # seconds between probes through the tunnel
: "${VPN_PROBE_FAILURES:=4}"   # consecutive failures before a reconnect

cli=adguardvpn-cli
log() { echo "[entrypoint] $*"; }

# Kill switch. Only root may open connections outside the tunnel: the VPN
# service itself and Docker's embedded DNS forwarder. Everything else sharing
# this namespace must run as a non-root uid, or it bypasses the switch.
# Replies to inbound connections (another container calling a service here)
# pass by conntrack. IPv6 is dropped whole; disable it with sysctls anyway.
iptables -F OUTPUT
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A OUTPUT -o 'tun+' -j ACCEPT
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m owner --uid-owner 0 -j ACCEPT
iptables -P OUTPUT DROP
ip6tables -P OUTPUT DROP 2>/dev/null || true
log "kill switch armed"

# Every `config set-*` echoes the whole configuration; show it once.
{
  $cli config set-mode TUN
  $cli config set-tun-device-name tun0
  $cli config set-tun-routing-mode AUTO
  $cli config set-change-system-dns off
  $cli config set-crash-reporting off
  $cli config set-telemetry off
  $cli config set-update-channel release
  $cli config set-show-hints off
} >/dev/null
$cli config show

vpn=
stop() {
  trap - TERM INT
  [[ -n $vpn ]] && kill "$vpn" 2>/dev/null
  $cli disconnect >/dev/null 2>&1 || true
  exit 0
}
trap stop TERM INT

while true; do
  # `login` prints the authorization link (docker logs) and waits for it to
  # be used; the link expires after 30 minutes, then a new one is printed.
  while [[ $($cli status 2>&1) == *"not logged in"* ]]; do
    log "not logged in: open the link below in a browser"
    $cli login </dev/null || true
  done

  # --boot: the CLI itself retries the connection indefinitely.
  $cli connect -l "$VPN_LOCATION" -y --no-fork --boot </dev/null &
  vpn=$!
  failures=0
  while sleep "$VPN_PROBE_INTERVAL" && kill -0 "$vpn" 2>/dev/null; do
    if probe.sh; then
      failures=0
      continue
    fi
    failures=$((failures + 1))
    log "probe failed ($failures/$VPN_PROBE_FAILURES)"
    if (( failures >= VPN_PROBE_FAILURES )); then
      log "tunnel is dead, reconnecting"
      kill "$vpn" 2>/dev/null || true
      break
    fi
  done
  wait "$vpn" || true
  vpn=
  log "VPN service stopped, restarting in 10s"
  sleep 10
done
