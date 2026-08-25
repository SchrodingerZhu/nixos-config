# NUT netclient — manifold as a SECONDARY of the workstation's upsd
# (ups-server.nix). When the APC UPS on the workstation reports a sustained
# outage (or low battery), the primary raises FSD and upsmon here runs
# SHUTDOWNCMD (`shutdown now`) immediately. Deliberate: manifold powers off
# with the rest of the fleet even though it has its own battery.
#
# Caveats:
#   * 192.168.0.92 is the workstation's DHCP lease on the T-Mobile router —
#     reserve it there, or upsmon just logs "UPS unavailable" forever and
#     never shuts down.
#   * A suspended laptop receives nothing; FSD only reaches it while awake.
#
# Secret: /persist/secrets/nut-remote.pass (NOT in git) — same password as
# the upsmon_remote user on the workstation.
{ ... }:
{
  power.ups = {
    enable = true;
    mode = "netclient";
    upsmon.monitor.apc = {
      system = "apc@192.168.0.92";
      user = "upsmon_remote";
      passwordFile = "/persist/secrets/nut-remote.pass";
      type = "secondary";
    };
  };
}
