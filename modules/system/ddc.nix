# DDC/CI brightness for EXTERNAL monitors — ddcutil/i2c-dev userspace path
# ONLY. The internal panel keeps its amdgpu backlight.
#
# HISTORY (do not re-add ddcci-driver here): the first version loaded the
# ddcci/ddcci-backlight kernel modules and instantiated ddcci clients at 0x37
# on every "AMDGPU DM i2c" bus at boot. On the Z13 (Strix Halo) that touched
# the INTERNAL eDP panel's DDC bus too and wedged amdgpu's display engine —
# PSR warnings from the vblank worker, black internal panel at the greeter,
# external output dropping after login, system-wide sluggishness, and one
# hard crash. None of the probes even bound (-19). If a kernel backlight
# for externals is ever wanted again, it must be scoped to CONNECTED
# non-eDP connectors via /sys/class/drm/<conn>/ddc — never a bus sweep.
#
# What remains: /dev/i2c-* access so ddcutil can drive external monitors'
# brightness on demand (e.g. `ddcutil setvcp 10 60`), and for anything else
# (DMS) that knows how to use ddcutil. ddcutil skips eDP panels by design.
{ pkgs, ... }:
{
  # /dev/i2c-* (group i2c) for unprivileged DDC/CI access.
  hardware.i2c.enable = true;
  users.users.schrodingerzy.extraGroups = [ "i2c" ];

  environment.systemPackages = [ pkgs.ddcutil ];
}
