# Automatic timezone (shared by both hosts): automatic-timezoned watches
# geoclue2 (WiFi-AP based geolocation; both machines have WiFi radios) and
# sets the zone via systemd-timedated whenever the location changes.
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
