# Automatic timezone (LAPTOP only): automatic-timezoned watches geoclue2 and
# sets the zone via systemd-timedated whenever the location changes. beacondb
# doesn't know the home APs, so the fix comes from the IP fallback — correct
# on the laptop (direct T-Mobile egress geolocates to the real city). The
# workstation pins a static zone instead: its egress is the ProtonVPN exit,
# which geolocates to the wrong coast (see hosts/workstation/default.nix).
#
# GOTCHA (cost a debugging session): systemd-timedated runs with only
# CAP_SYS_TIME, so /etc MUST be root-owned or set-timezone fails with
# EACCES. Impermanence recreates /etc each boot copying ownership from
# /persist/etc — keep /persist, /persist/etc, /persist/var owned root:root.
#
# time.timeZone must stay UNSET in the host configs — the upstream module
# hard-sets it to null and raises an eval error against any explicit value,
# so the daemon's choice can't be silently overridden at activation. Between
# boot and the first location fix the system runs UTC; the fix normally
# lands seconds after the network comes up (ephemeral root makes this a
# per-boot occurrence, which is fine).
{ ... }:
{
  services.automatic-timezoned.enable = true;
}
