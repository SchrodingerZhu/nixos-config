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
{ lib, pkgs, ... }:
let
  wg = "${pkgs.wireguard-tools}/bin/wg";

  address = "10.2.0.2/32";
  protonDns = "10.2.0.1";

  scTable = 200;
  markSc = 28528; # dst in sc set     -> secure-core
  markScWrap = 28529; # sc's encrypted pkts -> physical link
in
{
  # asymmetric replies from the policy-routed secure-core tunnel need loose rpf
  networking.firewall.checkReversePath = "loose";

  networking.wg-quick.interfaces = {
    # DEFAULT EXIT: US-CA (p2p config), full tunnel, catch-all.
    proton = {
      autostart = true;
      address = [ address ];
      privateKeyFile = "/persist/secrets/proton.key";
      peers = [
        {
          publicKey = "JtPZzImfe+HtDLTEPxsHLbOusQJfOwLyOYjNixNY0k8=";
          allowedIPs = [
            "0.0.0.0/0"
            "::/0"
          ];
          endpoint = "79.127.185.251:51820";
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
          publicKey = "lHEn/qdFKAZZjGWD3gAN1QBxuEZly7pSqaqRQRIW2hI=";
          allowedIPs = [
            "0.0.0.0/0"
            "::/0"
          ];
          endpoint = "79.135.104.68:51820";
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

      chain mark_dst {
        type route hook output priority mangle; policy accept;

        # DNS always rides the default tunnel to reach 10.2.0.1.
        udp dport 53 return
        tcp dport 53 return

        ip  daddr @sc_v4 meta mark set ${toString markSc}
        ip6 daddr @sc_v6 meta mark set ${toString markSc}
      }
    '';
  };

  # ---- policy-routing rules (boot oneshot; harmless when sc is down) ---------
  systemd.services.vpn-split-route = {
    description = "Policy-routing rules for the secure-core split tunnel";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-pre.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    path = [ pkgs.iproute2 ];
    # priorities sit ABOVE wg-quick's catch-all rules (~32764)
    script = ''
      add() { ip $1 rule add fwmark $2 table $3 priority $4 2>/dev/null || true; }
      for fam in "-4" "-6"; do
        add "$fam" ${toString markScWrap} main             4   # sc encrypted pkts -> physical
        add "$fam" ${toString markSc}     ${toString scTable}  6   # sensitive sites  -> secure-core
      done
    '';
    preStop = ''
      del() { ip $1 rule del fwmark $2 table $3 priority $4 2>/dev/null || true; }
      for fam in "-4" "-6"; do
        del "$fam" ${toString markScWrap} main             4
        del "$fam" ${toString markSc}     ${toString scTable}  6
      done
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
    };
  };
  # dnsmasq needs CAP_NET_ADMIN to add elements to the nftables sets.
  systemd.services.dnsmasq.serviceConfig.AmbientCapabilities = lib.mkForce [
    "CAP_NET_ADMIN"
    "CAP_NET_BIND_SERVICE"
  ];

  # ---- status helper ----  `sudo vpn status`
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "vpn" ''
      ip="${pkgs.iproute2}/bin/ip"
      nft="${pkgs.nftables}/bin/nft"
      case "''${1:-status}" in
        status)
          ${wg} show
          echo "--- ip rule ---"; $ip rule
          echo "--- secure-core table (${toString scTable}) ---"; $ip route show table ${toString scTable}
          echo "--- nft sc_v4 set ---"; $nft list set inet split-tunnel sc_v4 ;;
        *) echo "usage: vpn status   (run with sudo)" ;;
      esac
    '')
  ];
}
