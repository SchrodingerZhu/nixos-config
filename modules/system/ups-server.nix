# NUT netserver for the APC Back-UPS NS 1500M2 (USB HID) — workstation only.
#
# Topology: this host runs the driver (usbhid-ups) + upsd + upsmon as the
# PRIMARY; manifold (ups-client.nix) and spark (Ubuntu nut-client, configured
# by hand — /etc/nut there is not managed by this flake) connect as
# SECONDARIES over 3493/tcp.
#
# Power-down policy: after 120s continuously on battery (upssched timer,
# cancelled if mains returns), the primary raises FSD — all secondaries run
# their SHUTDOWNCMD immediately, then this host follows. NUT's standard
# low-battery FSD remains as backstop for outages shorter than the timer
# that still drain the battery.
#
# Privilege split: upsmon's NOTIFYCMD (upssched) and its CMDSCRIPT run as the
# unprivileged nutmon child, which cannot signal the root upsmon process. So
# the CMDSCRIPT only drops a flag file in /run/nut-upssched, and the nut-fsd
# path unit below runs `upsmon -c fsd` as root.
#
# Secrets: /persist/secrets/nut-{local,remote}.pass (NOT in git). The remote
# password is shared with manifold and spark.
#
# NOT enabled: POWERDOWNFLAG / ups-killpower (the UPS would cut its own
# output after FSD so BIOS "restore on AC" could auto-restart everything).
# Flip POWERDOWNFLAG back to its default if that behavior is wanted later.
{ config, pkgs, lib, ... }:
let
  fsdFlagDir = "/run/nut-upssched";
  schedCmd = pkgs.writeShellScript "upssched-cmd" ''
    case "$1" in
      onbatt)
        ${pkgs.util-linux}/bin/logger -t upssched "on battery for 120s -> requesting FSD"
        touch ${fsdFlagDir}/fsd
        ;;
      *)
        ${pkgs.util-linux}/bin/logger -t upssched "unhandled event: $1"
        ;;
    esac
  '';
in
{
  power.ups = {
    enable = true;
    mode = "netserver";
    openFirewall = true; # 3493/tcp

    ups.apc = {
      driver = "usbhid-ups";
      port = "auto";
      description = "APC Back-UPS NS 1500M2";
    };

    upsd.listen = [
      { address = "0.0.0.0"; } # localhost + LAN secondaries; auth via upsd.users
    ];

    users = {
      upsmon_local = {
        upsmon = "primary";
        passwordFile = "/persist/secrets/nut-local.pass";
      };
      upsmon_remote = {
        upsmon = "secondary";
        passwordFile = "/persist/secrets/nut-remote.pass";
      };
    };

    upsmon = {
      monitor.apc = {
        system = "apc@localhost";
        user = "upsmon_local";
        type = "primary";
      };
      settings = {
        # EXEC makes upsmon invoke NOTIFYCMD (upssched) for these events;
        # without it the 120s timer never starts.
        NOTIFYFLAG = [
          [ "ONBATT" "SYSLOG+EXEC" ]
          [ "ONLINE" "SYSLOG+EXEC" ]
        ];
        POWERDOWNFLAG = lib.mkForce null; # see header
      };
    };

    schedulerRules = builtins.toString (
      pkgs.writeText "upssched.conf" ''
        CMDSCRIPT ${schedCmd}
        PIPEFN ${fsdFlagDir}/upssched.pipe
        LOCKFN ${fsdFlagDir}/upssched.lock
        AT ONBATT * START-TIMER onbatt 120
        AT ONLINE * CANCEL-TIMER onbatt
      ''
    );
  };

  # Runtime dir writable by nutmon (upssched pipe/lock + the fsd flag).
  systemd.tmpfiles.rules = [ "d ${fsdFlagDir} 0770 root nutmon" ];

  # Root-side FSD trigger: flag file -> coordinated shutdown of the fleet.
  systemd.paths.nut-fsd = {
    description = "Watch for the upssched power-down flag";
    wantedBy = [ "multi-user.target" ];
    pathConfig.PathExists = "${fsdFlagDir}/fsd";
  };
  systemd.services.nut-fsd = {
    description = "Force shutdown of all UPS-fed machines (upsmon FSD)";
    environment = {
      NUT_CONFPATH = "/etc/nut";
      NUT_STATEPATH = "/var/lib/nut";
    };
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${config.power.ups.package}/sbin/upsmon -c fsd";
    };
  };
}
