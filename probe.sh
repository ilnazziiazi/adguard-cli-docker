#!/bin/bash
# Healthcheck: succeeds only through the tunnel. Binding to tun0 fails while
# the interface is absent, and a silently dead tunnel times out.
exec curl -sS --interface tun0 --max-time 10 -o /dev/null "${VPN_PROBE_URL:-https://1.1.1.1/}"
