# Laptop-only bits for the ROG Flow Z13 (Strix Halo).
#   * asusctl + supergfxctl (ROG platform daemons: fan curves, per-key RGB,
#     charge threshold, gfx-mode; supergfxctl is a no-op on this iGPU-only
#     model but harmless -- kept so `asusctl` sees the whole service group).
#   * power-profiles-daemon (PPD) as the battery/performance policy daemon.
#     Integrates with the xdg portal so GNOME/DMS toggles Just Work; conflicts
#     with tuned/TLP so those must NOT be enabled at the same time.
#   * iio-sensor-proxy: accelerometer + ambient-light sensor D-Bus service.
#     iwlwifi/GNOME/niri consume it for auto-rotate + auto-brightness. The Z13
#     is a detachable tablet so the accelerometer matters.
#   * fprintd: libfprint fingerprint daemon (Flow Z13 has a power-button fp
#     reader). Enabled here + wired into PAM login/sudo so it works alongside
#     the existing password / U2F fallbacks (control=sufficient).
{ pkgs, lib, ... }:
let
  # The Z13 panel's firmware rescales amdgpu_bl1 brightness writes upward
  # (~x1.016); raw values >= 64600 overflow 16 bits and wrap to duty cycle 0,
  # turning the screen OFF at "100%". 64400 already yields the true hardware
  # maximum (actual_brightness = 65535), so clamping there loses nothing.
  # Runs on every backlight change uevent, so it also covers the DMS slider
  # and anything else writing to sysfs, not just the niri brightnessctl keys.
  backlightClamp = pkgs.writeShellScript "backlight-clamp" ''
    bl="/sys$DEVPATH"
    cur=$(cat "$bl/brightness") || exit 0
    if [ "$cur" -gt 64400 ]; then
      echo 64400 > "$bl/brightness"
    fi
  '';
in
{
  # --- eDP stability: disable panel power-saving in amdgpu DC --------------
  # The Z13 panel wedges in the PSR / idle-screen-management path (WARNING at
  # mod_power_set_psr_event via dm_ism_commit_idle_optimization_state, panel
  # stops updating until reboot; seen on 7.2.0-cachyos with and without any
  # DDC experiments). Disable the involved features:
  #   0x010 PSR | 0x200 PSR-SU | 0x400 Panel Replay | 0x800 IPS  = 0xE10
  # Costs some battery; remove bits once a kernel fixes the ISM path.
  boot.kernelParams = [ "amdgpu.dcdebugmask=0xE10" ];

  # --- ASUS ROG platform daemons -------------------------------------------
  services.asusd.enable = true;
  services.supergfxd.enable = true;

  # --- Battery / performance policy ----------------------------------------
  services.power-profiles-daemon.enable = true;

  # UPower: battery stats over D-Bus. PPD only does perf profiles; DMS's
  # battery widget needs the UPower daemon to see the battery at all.
  services.upower.enable = true;

  # --- Sensors: accelerometer (auto-rotate) + ALS (auto-brightness) --------
  hardware.sensor.iio.enable = true;

  # --- Backlight: let logind ignore the power button in tablet mode --------
  # Keep default lid behavior (suspend) since the Z13 tablet has a real hinge.
  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "ignore"; # docked -> don't sleep
  };

  # --- Fingerprint reader (libfprint) --------------------------------------
  # PAM control = "sufficient": fingerprint OR password OR U2F all valid.
  services.fprintd.enable = true;
  security.pam.services = {
    login.fprintAuth = true;
    sudo.fprintAuth = true;
    # niri screen-lock (dms-locker uses PAM stack "gtklock" via DMS defaults).
    swaylock.fprintAuth = true;
  };

  # --- Userland helpers -----------------------------------------------------
  environment.systemPackages = with pkgs; [
    asusctl # `asusctl profile`, `asusctl fan-curve`, ...
    supergfxctl # `supergfxctl -g` (integrated-only here but harmless)
    powertop # `sudo powertop` for one-shot tunables + reporting
    brightnessctl # backlight control from niri keybinds
  ];

  # --- Firmware updater ----------------------------------------------------
  # fwupdmgr can push newer AMD/AGESA microcode + touchpad/fp reader firmware.
  services.fwupd.enable = true;

  # --- AMD XDNA NPU (Ryzen AI Max+ 395, XDNA2) -----------------------------
  # Kernel module `amdxdna` is upstream since 6.11 and is already present in
  # the CachyOS latest kernel we run (verified via `modinfo amdxdna`). Force
  # it into the initial module set so /dev/accel/accel0 exists at boot for
  # user-space runtimes.
  #
  # Firmware blobs (/lib/firmware/amdnpu/*.xclbin, `npu_1.sbin`, ...) come
  # from `linux-firmware`, which is pulled in by
  # `hardware.enableRedistributableFirmware = true` (set in modules/system/boot.nix).
  #
  # USERSPACE: AMD's Ryzen AI stack (XRT with the xdna_shim plugin, ROCm's
  # `iree-xdna` runtime, or ONNX Runtime with the "vitisai" EP) is NOT yet in
  # nixpkgs. Two recommended paths:
  #   1) Run the AMD-published Ubuntu image inside distrobox (already enabled
  #      via `virtualisation.podman.enable`):
  #          distrobox create -i rocm/dev-ubuntu-24.04:latest xdna
  #          distrobox enter xdna
  #      then follow AMD's Ryzen AI XRT install docs INSIDE the container.
  #      The container gets access to /dev/accel/accel0 via podman's default
  #      device passthrough; verify inside with `ls /dev/accel/`.
  #   2) Build XRT/xdna-driver from source with an overlay (out of scope for
  #      the initial install -- ping me when you need it).
  boot.kernelModules = [ "amdxdna" ];

  # /dev/accel/accel0 gets ownership root:render 0660 from upstream udev
  # rules. Make sure the user is in `render` so runtimes work non-root.
  users.users.schrodingerzy.extraGroups = [ "render" ];

  # Explicit udev rule as belt-and-braces (some distros ship rules under
  # /usr/lib/udev/rules.d, which don't apply on NixOS): mode 0660,
  # group=render for anything the amdxdna driver creates in /dev/accel.
  services.udev.extraRules = ''
    SUBSYSTEM=="accel", KERNEL=="accel[0-9]*", MODE="0660", GROUP="render"
    ACTION=="change", SUBSYSTEM=="backlight", KERNEL=="amdgpu_bl*", RUN+="${backlightClamp}"
    # USB hubs default to autosuspend with 0ms delay; the USB-C dock hub
    # renegotiates its whole link on suspend/resume (full-tree disconnects,
    # input dropouts every few seconds). Keep hubs powered.
    ACTION=="add", SUBSYSTEM=="usb", ATTR{bDeviceClass}=="09", TEST=="power/control", ATTR{power/control}="on"
  '';
}
