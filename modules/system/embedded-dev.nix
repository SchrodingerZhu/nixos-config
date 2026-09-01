# Embedded development: debug-probe USB access without root.
#
# SEGGER J-Link (incl. the J-Link OB on Renesas EK boards, VID 1366) enumerates
# as a vendor-class USB interface plus a CDC-ACM virtual COM port. The USB
# device node defaults to root:root 0664, so libjlinkarm/pyocd/probe-rs cannot
# open it as a normal user. Grant the seated user access via the uaccess tag,
# keep ModemManager off the VCOM, and put the user in `dialout` for /dev/ttyACM*.
#
# The per-project toolchain (ATfE clang, J-Link CLI, pyocd, OpenOCD, probe-rs)
# lives in the project flake's devShell, not here.
{ ... }:
{
  users.users.schrodingerzy.extraGroups = [ "dialout" ];

  services.udev.extraRules = ''
    # SEGGER J-Link / J-Link OB (all product IDs) — seated-user access + ModemManager ignore
    SUBSYSTEM=="usb", ATTRS{idVendor}=="1366", MODE="0660", GROUP="dialout", TAG+="uaccess", ENV{ID_MM_DEVICE_IGNORE}="1"
    SUBSYSTEM=="tty",  ATTRS{idVendor}=="1366", MODE="0660", GROUP="dialout", TAG+="uaccess", ENV{ID_MM_DEVICE_IGNORE}="1"
    # Renesas E2/E2 Lite and RA USB-boot (DFU/CDC) interfaces
    SUBSYSTEM=="usb", ATTRS{idVendor}=="045b", MODE="0660", GROUP="dialout", TAG+="uaccess", ENV{ID_MM_DEVICE_IGNORE}="1"
    # CMSIS-DAP probes (Arm DAPLink & clones) via hidraw/usb
    SUBSYSTEM=="usb",    ATTRS{product}=="*CMSIS-DAP*", MODE="0660", GROUP="dialout", TAG+="uaccess"
    SUBSYSTEM=="hidraw", ATTRS{product}=="*CMSIS-DAP*", MODE="0660", GROUP="dialout", TAG+="uaccess"
  '';
}
