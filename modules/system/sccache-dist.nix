# sccache-dist SCHEDULER (workstation only): dispatches Rust compile jobs
# from any client to the registered build servers — both hosts run one via
# modules/system/sccache-builder.nix — per
# https://brokenco.de/2025/01/05/sccache-distributed-compilation.html.
#
# How this works with Nix toolchains: the CLIENT tars its devShell's rustc and
# every linked library with absolute /nix/store paths preserved. A build
# server unpacks that content-addressed archive as an overlayfs lowerdir and
# runs the compile inside bubblewrap, so the store paths resolve WITHOUT nix
# or any toolchain installed on it. Only compile steps distribute (linking is
# always local); rustc only (C toolchains would need explicit
# [dist.toolchains]); every failure mode falls back to a local compile.
#
# Config: /persist/secrets/sccache/scheduler.toml (NOT in git — embeds the
# client + server auth tokens).
{ pkgs, ... }:
let
  sccacheDist = pkgs.sccache.override { distributed = true; };
in
{
  systemd.services.sccache-scheduler = {
    description = "sccache-dist scheduler";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    environment.SCCACHE_NO_DAEMON = "1"; # daemonize() honors this -> simple unit
    serviceConfig = {
      ExecStart = "${sccacheDist}/bin/sccache-dist scheduler --syslog info --config /persist/secrets/sccache/scheduler.toml";
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };

  networking.firewall.allowedTCPPorts = [ 10600 ];
}
