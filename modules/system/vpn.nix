# ProtonVPN over WireGuard (wg-quick): default tunnel + DESTINATION-based carve-out.
#
# Two tunnels run at once:
#   * proton      -- DEFAULT/catch-all for everything (Steam, games, DDNet, web).
#                    Uses the US-CA "p2p" config (NAT-PMP / Moderate NAT enabled),
#                    which replaced the old "daily" config: both were the SAME
#                    server, and two peers sharing internal IP 10.2.0.2 on one
#                    server conflict, so we keep just this one.
#   * proton-sc   -- secure-core, for SENSITIVE sites chosen by DESTINATION.
#
# A local dnsmasq resolves the sensitive domains and auto-fills nftables sets with
# the answers; an nft `type route hook output` chain marks packets whose dst is in
# a set, and policy-routing sends them out secure-core instead of the default.
#
# The sensitive site list lives in /persist/secrets/vpn-sc-domains.conf (root 0600,
# NOT in git; /persist/secrets is .gitignored and survives the ephemeral-root
# wipe); only the generic set names (sc_v4/sc_v6) appear in this repo.
#
# DNS: dnsmasq is the system resolver (127.0.0.1), forwarding ONLY to Proton's
# 10.2.0.1 over the default tunnel (no-resolv => never the ISP). Port 53 is exempt
# from marking so resolution always rides the default tunnel.
#
# SECRETS: only PRIVATE KEYS + the sensitive domain list are secret. Server public
# keys / endpoints are not. KEY EXPIRY: Proton certs expire ~1 year; renew via the
# dashboard "Extend" (keeps keys). Check handshakes with `sudo wg show`.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  wg = "${pkgs.wireguard-tools}/bin/wg";

  address = "10.2.0.2/32"; # identical in every Proton config (per-key, not per-device)
  protonDns = "10.2.0.1";

  # Per-host peers: each machine has its OWN Proton device certs — never share
  # a cert across machines (one WG pubkey = one server-side peer tracking a
  # single roaming endpoint; two clients on the same key repoint it with every
  # keepalive and starve each other of return traffic).
  #   workstation: default US-CA p2p       + sc CH-US (79.135.104.68)
  #   manifold:    default US-NJ "mobile"  + sc CH-US#3 "mobile-sc"
  isManifold = config.networking.hostName == "manifold";
  protonPeer =
    if isManifold then
      {
        publicKey = "6Ct2qC5B3ayxBtkV2y6ScFzYcLD/6fLmtMmHPCJTAVU="; # US-NJ#63
        endpoint = "163.5.171.29:51820";
      }
    else
      {
        publicKey = "JtPZzImfe+HtDLTEPxsHLbOusQJfOwLyOYjNixNY0k8="; # US-CA p2p
        endpoint = "79.127.185.251:51820";
      };
  scPeer =
    if isManifold then
      {
        publicKey = "znjz1X8oDeciB6/JHNvbOQxIkBPvA9gP5dIXpesm+Fc="; # CH-US#3
        endpoint = "79.135.104.22:51820";
      }
    else
      {
        publicKey = "lHEn/qdFKAZZjGWD3gAN1QBxuEZly7pSqaqRQRIW2hI="; # CH-US
        endpoint = "79.135.104.68:51820";
      };

  # We do NOT let wg-quick auto-install its full-tunnel ip-rules: it picks
  # non-deterministic priorities (seen at 0 and at 2/3 across boots) and orders
  # its catch-all BEFORE its own suppress rule, which swallows LAN + our marked
  # traffic into the tunnel. Instead each interface gets an explicit `table`, and
  # we own every ip-rule below with fixed priorities.
  protonTable = 100; # default tunnel's default route lives here
  scTable = 200; # secure-core's default route lives here

  markProtonWrap = 28527; # proton's encrypted pkts -> physical link
  markSc = 28528; # dst in sc set        -> secure-core
  markScWrap = 28529; # sc's encrypted pkts  -> physical link
  markDirect = 28530; # group `novpn`        -> direct (physical link, no VPN)

  bypassGroup = "novpn";
  gidNovpn = 3300; # pinned so nftables can match by numeric gid
in
{
  # asymmetric replies from the policy-routed secure-core tunnel need loose rpf
  networking.firewall.checkReversePath = "loose";

  # wg-quick uses fwmark to keep an interface's OWN encrypted packets out of the
  # tunnel; with an explicit `table` it won't set that up, so we set the fwmark in
  # postUp and route those marks to the physical link ourselves (rules below).
  networking.wg-quick.interfaces = {
    # DEFAULT EXIT: US-CA (p2p config). table=100 => routes go in table 100 only;
    # we send unmarked traffic there via a low-priority rule below.
    proton = {
      autostart = true;
      address = [ address ];
      privateKeyFile = "/persist/secrets/proton.key";
      table = toString protonTable;
      postUp = "${wg} set proton fwmark ${toString markProtonWrap}";
      peers = [
        {
          inherit (protonPeer) publicKey endpoint;
          allowedIPs = [
            "0.0.0.0/0"
            "::/0"
          ];
          persistentKeepalive = 25;
        }
      ];
    };

    # SECONDARY EXIT: secure-core. table=200 so it does NOT steal the default
    # route; only traffic marked for the sensitive-site sets is routed here. Its
    # own encrypted packets are tagged (postUp) so they egress the physical link
    # instead of being swallowed by the default catch-all tunnel.
    proton-sc = {
      autostart = true;
      address = [ address ];
      privateKeyFile = "/persist/secrets/proton-sc.key";
      table = toString scTable;
      postUp = "${wg} set proton-sc fwmark ${toString markScWrap}";
      peers = [
        {
          inherit (scPeer) publicKey endpoint;
          allowedIPs = [
            "0.0.0.0/0"
            "::/0"
          ];
          persistentKeepalive = 25;
        }
      ];
    };
  };

  # ---- nftables: sensitive-site destination sets + marking chain -------------
  networking.nftables.tables.split-tunnel = {
    family = "inet";
    content = ''
      set sc_v4 { type ipv4_addr; }
      set sc_v6 { type ipv6_addr; }
      set direct_v4 { type ipv4_addr; }
      set direct_v6 { type ipv6_addr; }

      chain mark_dst {
        type route hook output priority mangle; policy accept;

        # DNS always rides the default tunnel to reach 10.2.0.1.
        udp dport 53 return
        tcp dport 53 return

        # Dev-infra destinations (github / nix caches / crates / pypi) go
        # DIRECT: large downloads break mid-stream through the tunnel. Sets are
        # dnsmasq-filled (nftset entries below). BEFORE the sc lines, so the
        # sensitive-site list wins if a domain ever appears in both.
        ip  daddr @direct_v4 meta mark set ${toString markDirect}
        ip6 daddr @direct_v6 meta mark set ${toString markDirect}

        ip  daddr @sc_v4 meta mark set ${toString markSc}
        ip6 daddr @sc_v6 meta mark set ${toString markSc}

        # Apps in the `novpn` group go DIRECT -- last, so it overrides the above.
        meta skgid ${toString gidNovpn} meta mark set ${toString markDirect}
      }

      chain srcnat {
        type nat hook postrouting priority srcnat; policy accept;
        # Direct (novpn) sockets get the tunnel's source IP (10.2.0.2) chosen at
        # connect-time, BEFORE the mark reroutes them to the physical link -- so
        # they'd leave with a martian source and get dropped (UDP/IPv4 especially;
        # TCP slipped by over IPv6). Masquerade to the real physical IP; conntrack
        # restores the reply. v6 already gets a real source, so v4 only.
        meta nfproto ipv4 meta mark ${toString markDirect} masquerade
      }
    '';
  };

  # wg routing needs this so fwmark-routed encrypted packets aren't dropped by
  # source-address validation (wg-quick sets it in auto mode; we set it manually).
  boot.kernel.sysctl."net.ipv4.conf.all.src_valid_mark" = 1;

  # ---- policy-routing rules: WE own the whole rule table now -----------------
  # Ordered by priority (lower = first). The default route lives in table 100
  # (proton) / 200 (sc); the physical default stays in `main`.
  #   100-103  marked traffic -> its exit (encrypted pkts + direct -> physical)
  #   150      `main` minus its default -> keeps LAN/link routes (e.g. ssh spark)
  #   200      everything else (unmarked) -> proton tunnel (table 100)
  systemd.services.vpn-split-route = {
    description = "Policy-routing rules for the VPN split tunnels";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-pre.target" ];
    # re-apply if wg interfaces restart (their tables/fwmarks are prerequisites)
    partOf = [ "wg-quick-proton.service" ];
    wants = [ "wg-quick-proton.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    path = [ pkgs.iproute2 ];
    script = ''
      r() { ip $1 rule add $2 priority $3 2>/dev/null || true; }
      for f in "-4" "-6"; do
        r "$f" "fwmark ${toString markProtonWrap} table main"          100  # proton enc -> phys
        r "$f" "fwmark ${toString markScWrap}     table main"          101  # sc enc     -> phys
        r "$f" "fwmark ${toString markDirect}     table main"          102  # novpn apps -> direct
        r "$f" "fwmark ${toString markSc}         table ${toString scTable}" 103  # sensitive -> sc
        r "$f" "table main suppress_prefixlength 0"                    150  # LAN/link routes
        r "$f" "table ${toString protonTable}"                        200  # default -> proton
      done

      # Proton WireGuard is IPv4-only: the interfaces get no inet6 address, yet
      # wg-quick still routes ::/0 into the tunnel (from allowedIPs). On a LAN
      # that offers IPv6, apps that try IPv6 first (browsers / happy-eyeballs)
      # send their first connection into the v4-only tunnel, where it has no
      # source address and is silently dropped -- no reset comes back, so the app
      # hangs until it times out and only then falls back to v4 ("works after a
      # while" / "can't connect unless I go direct"). Blackhole internet IPv6 in
      # the VPN tables (metric 1 beats wg-quick's dev-<if> default at 1024) so a
      # v6 connect returns ENETUNREACH IMMEDIATELY -> instant v4 fallback through
      # the tunnel, and no v6 ever leaks past the VPN. LAN/link IPv6 is untouched:
      # it still resolves via the priority-150 suppress_prefixlength rule.
      ip -6 route replace blackhole default table ${toString protonTable} metric 1
      ip -6 route replace blackhole default table ${toString scTable} metric 1
    '';
    preStop = ''
      d() { ip $1 rule del priority $2 2>/dev/null || true; }
      for f in "-4" "-6"; do
        for p in 100 101 102 103 150 200; do d "$f" "$p"; done
      done
      ip -6 route del blackhole default table ${toString protonTable} metric 1 2>/dev/null || true
      ip -6 route del blackhole default table ${toString scTable} metric 1 2>/dev/null || true
    '';
  };

  # ---- dnsmasq: resolver that auto-fills the sensitive destination sets ------
  services.dnsmasq = {
    enable = true;
    settings = {
      no-resolv = true; # never fall back to ISP resolvers
      server = [ protonDns ]; # forward only to Proton DNS (over the default tunnel)
      cache-size = 1000;
      # Sensitive sites -> sc sets. List kept OUT of the repo:
      conf-file = "/persist/secrets/vpn-sc-domains.conf";
      # Dev-infra domains -> direct sets (public list, lives here). A bare
      # /domain/ matches the domain AND all subdomains (cache.nixos.org via
      # nixos.org, niri.cachix.org via cachix.org, static.crates.io, ...).
      # Resolution itself still rides the tunnel; only the payload goes direct.
      nftset = [
        "/github.com/githubusercontent.com/ghcr.io/4#inet#split-tunnel#direct_v4,6#inet#split-tunnel#direct_v6"
        "/nixos.org/cachix.org/attic.xuyh0120.win/4#inet#split-tunnel#direct_v4,6#inet#split-tunnel#direct_v6"
        "/crates.io/rust-lang.org/4#inet#split-tunnel#direct_v4,6#inet#split-tunnel#direct_v6"
        "/pypi.org/pythonhosted.org/4#inet#split-tunnel#direct_v4,6#inet#split-tunnel#direct_v6"
        # geoclue's IP-fallback geolocation must see the REAL egress IP or
        # automatic-timezoned (manifold) follows the VPN exit's timezone.
        "/beacondb.net/4#inet#split-tunnel#direct_v4,6#inet#split-tunnel#direct_v6"
      ];
    };
  };
  # dnsmasq needs CAP_NET_ADMIN to add elements to the nftables sets.
  systemd.services.dnsmasq.serviceConfig.AmbientCapabilities = lib.mkForce [
    "CAP_NET_ADMIN"
    "CAP_NET_BIND_SERVICE"
  ];

  # ---- direct (VPN-bypass) group + membership --------------------------------
  # Sockets created under group `novpn` are marked (see the nft chain) and routed
  # out the physical link. NOTE: log out/in after the first rebuild so your shell
  # picks up the new group membership.
  users.groups.${bypassGroup}.gid = gidNovpn;
  users.users.schrodingerzy.extraGroups = [ bypassGroup ];

  # ---- helpers + launchers ---------------------------------------------------
  environment.systemPackages = [
    # `sudo vpn status` / `sudo vpn restart`
    (pkgs.writeShellScriptBin "vpn" ''
      ip="${pkgs.iproute2}/bin/ip"
      nft="${pkgs.nftables}/bin/nft"
      systemctl="${pkgs.systemd}/bin/systemctl"
      case "''${1:-status}" in
        status)
          ${wg} show
          echo "--- ip rule ---"; $ip rule
          echo "--- secure-core table (${toString scTable}) ---"; $ip route show table ${toString scTable}
          echo "--- nft sc_v4 set ---"; $nft list set inet split-tunnel sc_v4 ;;
        restart)
          # One-shot recovery when the tunnels wedge: bounce both wg-quick
          # interfaces (this re-runs their postUp fwmark setup), then re-apply the
          # policy-routing rules + IPv6 blackhole. dnsmasq is restarted last so it
          # re-establishes its forwarder over the freshly-rebuilt default tunnel.
          echo ">> restarting proton tunnels + routing…"
          $systemctl restart wg-quick-proton.service wg-quick-proton-sc.service
          $systemctl restart vpn-split-route.service
          $systemctl restart dnsmasq.service
          echo ">> done. handshakes:"; ${wg} show all latest-handshakes ;;
        *) echo "usage: vpn {status|restart}   (run with sudo)" ;;
      esac
    '')

    # `direct CMD…` -- run any one-off command outside the VPN. Per-app forcing
    # is done by wrapping the package itself (see modules/home/packages.nix).
    # `sg` keeps your uid + supplementary groups; GPU/audio access is by logind
    # seat ACL, not group, so it is unaffected.
    (pkgs.writeShellScriptBin "direct" ''
      exec sg ${bypassGroup} -c "$*"
    '')
  ];
}
