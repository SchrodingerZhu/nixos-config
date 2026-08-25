# DDC/CI brightness for EXTERNAL monitors (the internal panel already has
# amdgpu_bl1). The ddcci-backlight kernel module exposes DDC/CI-capable
# monitors (e.g. the LG UltraFine 4K) as regular /sys/class/backlight
# devices, so brightnessctl, the niri brightness keys and the DMS slider all
# work on them unchanged. Shared by both hosts (laptop + workstation); which
# connector the monitor hangs off doesn't matter.
{ config, pkgs, ... }:
let
  # Kernel 7.2 dropped strncpy from the in-kernel string API; upstream
  # ddcci-driver-linux (0.4.5-unstable-2025-09-27) still uses it in five
  # sysfs show handlers. strscpy is a drop-in there: the sources are small
  # fixed-size arrays (<< PAGE_SIZE) and the handlers compute the returned
  # length separately via strnlen. Drop this override once upstream catches up.
  ddcciDriver = config.boot.kernelPackages.ddcci-driver.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      substituteInPlace ddcci/ddcci.c --replace-fail "strncpy(" "strscpy("
    '';
  });

  # ddcci's autoprobe is unreliable on amdgpu (the module loads before the
  # connector's DDC i2c bus exists, or skips it). Explicitly instantiate a
  # ddcci client at the standard DDC address 0x37 on every AMDGPU display
  # i2c bus that doesn't have one yet. Idempotent, and harmless on busses
  # without a monitor: the probe just fails and the slot is released.
  ddcciProbe = pkgs.writeShellScript "ddcci-probe" ''
    for adapter in /sys/bus/i2c/devices/i2c-*; do
      name=$(cat "$adapter/name" 2>/dev/null) || continue
      case "$name" in
        "AMDGPU DM i2c"*) ;; # display-connector busses only (not aux/SMBus)
        *) continue ;;
      esac
      n=''${adapter##*/i2c-}
      [ -e "$adapter/$n-0037" ] && continue
      echo ddcci 0x37 > "$adapter/new_device" 2>/dev/null || true
    done
  '';
in
{
  # /dev/i2c-* (group i2c) so ddcutil works unprivileged for diagnostics.
  hardware.i2c.enable = true;
  users.users.schrodingerzy.extraGroups = [ "i2c" ];

  boot.extraModulePackages = [ ddcciDriver ];
  boot.kernelModules = [
    "i2c-dev"
    "ddcci"
    "ddcci-backlight"
  ];

  environment.systemPackages = [ pkgs.ddcutil ]; # `ddcutil detect`, `setvcp 10 <n>`

  # Instantiate on every monitor (un)plug/DPMS event...
  services.udev.extraRules = ''
    ACTION=="add|change", SUBSYSTEM=="drm", KERNEL=="card[0-9]*", RUN+="${ddcciProbe}"
  '';

  # ...and once late in boot as belt-and-braces (the coldplug drm event can
  # fire before all display i2c busses exist).
  systemd.services.ddcci-probe = {
    description = "Instantiate ddcci devices on AMDGPU display i2c busses";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${ddcciProbe}";
    };
  };
}
