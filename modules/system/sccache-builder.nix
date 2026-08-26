# sccache-dist BUILD SERVER (both hosts): registers with the workstation's
# scheduler (modules/system/sccache-dist.nix) so the whole fleet's cores form
# one compile pool — builds started on either machine fan out to both.
#
# Per-host config: /persist/secrets/sccache/server.toml (NOT in git — embeds
# the scheduler auth token). public_addr must be THIS host's LAN IP
# (workstation .92, manifold .60 — both DHCP-reserved): the scheduler binds
# the server token to that address and checks heartbeat source IPs, so a
# wrong/changed IP means 401 invalid_bearer_token_mismatched_address.
#
# Runs as root (the overlay builder mounts overlayfs); bwrap_path in
# server.toml points at /run/current-system/sw/bin/bwrap. On the laptop,
# suspend mid-job just makes those compiles fall back to their client —
# sccache degrades gracefully.
{ pkgs, ... }:
let
  sccacheDist = pkgs.sccache.override { distributed = true; };
in
{
  environment.systemPackages = [ pkgs.bubblewrap ];

  systemd.services.sccache-server = {
    description = "sccache-dist build server";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    environment.SCCACHE_NO_DAEMON = "1"; # daemonize() honors this -> simple unit
    serviceConfig = {
      ExecStart = "${sccacheDist}/bin/sccache-dist server --syslog info --config /persist/secrets/sccache/server.toml";
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };

  # Toolchain archive cache + overlay build scratch (ephemeral root is fine —
  # clients re-upload toolchains after a reboot, content-addressed and cheap).
  systemd.tmpfiles.rules = [ "d /var/cache/sccache-dist 0700 root root -" ];

  networking.firewall.allowedTCPPorts = [ 10501 ]; # clients connect directly
}
