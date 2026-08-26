# sccache-dist scheduler + build server (workstation only): manifold (and the
# workstation itself) ship Rust compile jobs here, per
# https://brokenco.de/2025/01/05/sccache-distributed-compilation.html.
#
# How this works with Nix toolchains: the CLIENT tars its devShell's rustc and
# every linked library with absolute /nix/store paths preserved. The server
# unpacks that content-addressed archive as an overlayfs lowerdir and runs the
# compile inside bubblewrap, so the store paths resolve WITHOUT nix or any
# toolchain installed here. Only compile steps distribute (linking is always
# local); rustc only (C toolchains would need explicit [dist.toolchains]);
# every failure mode falls back to a local compile on the client.
#
# Config files live in /persist/secrets/sccache/{scheduler,server}.toml (NOT
# in git — they embed the auth tokens). The server runs as root: the overlay
# builder needs to mount overlayfs. bwrap_path in server.toml points at
# /run/current-system/sw/bin/bwrap, hence bubblewrap in systemPackages.
{ pkgs, ... }:
let
  sccacheDist = pkgs.sccache.override { distributed = true; };
in
{
  environment.systemPackages = [ pkgs.bubblewrap ];

  systemd.services.sccache-scheduler = {
    description = "sccache-dist scheduler";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    serviceConfig = {
      # sccache-dist daemonizes (fork + parent exit) with no foreground flag.
      Type = "forking";
      ExecStart = "${sccacheDist}/bin/sccache-dist scheduler --syslog info --config /persist/secrets/sccache/scheduler.toml";
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };

  systemd.services.sccache-server = {
    description = "sccache-dist build server";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [
      "network-online.target"
      "sccache-scheduler.service"
    ];
    serviceConfig = {
      # Daemonizes like the scheduler.
      Type = "forking";
      ExecStart = "${sccacheDist}/bin/sccache-dist server --syslog info --config /persist/secrets/sccache/server.toml";
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };

  # Toolchain archive cache + overlay build scratch (ephemeral root is fine —
  # clients re-upload toolchains after a reboot, content-addressed and cheap).
  systemd.tmpfiles.rules = [ "d /var/cache/sccache-dist 0700 root root -" ];

  # 10600 scheduler (clients + server), 10501 server (clients connect directly).
  networking.firewall.allowedTCPPorts = [
    10600
    10501
  ];
}
