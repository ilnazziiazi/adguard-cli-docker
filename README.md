# adguard-cli-docker

[AdGuard VPN CLI](https://github.com/AdguardTeam/AdGuardVPNCLI) (official,
closed-source binary) in TUN mode, supervised for a shared Docker network
namespace: other containers join it with `network_mode: service:<name>` and
all their traffic leaves through the VPN.

What the entrypoint does, in order:

1. Arms a kill switch with iptables: outbound traffic is allowed only through
   `tun0`, plus connections opened by root (the VPN service itself and
   Docker's DNS forwarder). Containers sharing the namespace must run as a
   non-root uid, otherwise they bypass the switch.
2. Prints the authorization link (`docker logs`) until the session exists,
   then runs `adguardvpn-cli connect --no-fork --boot`.
3. Probes `https://1.1.1.1/` through `tun0` every 30 s. After 4 consecutive
   failures it restarts the VPN service **inside the container**: the
   namespace survives, joined containers keep their network.

The container never exits because of VPN trouble; the session lives in
`/root/.local/share/adguardvpn-cli`, together with a generated `machine-id`
the CLI needs to recognise it. Give the container a fixed `hostname:` too:
the session is also bound to it.

## Run

```yaml
services:
  adguardvpn:
    image: ghcr.io/ilnazziiazi/adguard-cli-docker:1.8.2-2
    hostname: adguardvpn
    cap_add: [NET_ADMIN]
    devices: [/dev/net/tun]
    sysctls:
      - net.ipv6.conf.all.disable_ipv6=1
      - net.ipv6.conf.default.disable_ipv6=1
    environment:
      VPN_LOCATION: DE
    volumes:
      - ./data:/root/.local/share/adguardvpn-cli
  app:
    image: ...
    user: "1000:1000"            # not root: see the kill switch above
    network_mode: service:adguardvpn
    depends_on:
      adguardvpn:
        condition: service_healthy
```

First start: `docker logs -f adguardvpn`, open the link, log in.

| Variable | Default | Meaning |
| --- | --- | --- |
| `VPN_LOCATION` | `DE` | city, country or ISO code |
| `VPN_PROBE_URL` | `https://1.1.1.1/` | fetched through `tun0` by the probe |
| `VPN_PROBE_INTERVAL` | `30` | seconds between probes |
| `VPN_PROBE_FAILURES` | `4` | consecutive failures before a reconnect |

## Build

Tags are `<cli version>-<build>`; bump `BUILD` when only the scripts change.

```sh
make build                       # local image, linux/amd64
make push                        # same, pushed to ghcr.io
make push CLI_VERSION=1.8.3      # new upstream release
```

The archive is downloaded from GitHub Releases and its signature is verified
against `adguard-release.asc` (fingerprint
`2864 5AC9 776E C4C0 0BCE 2AFC 0FE6 41E7 235E 2EC6`, from keys.openpgp.org).
