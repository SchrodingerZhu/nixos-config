# Boot: systemd-boot (UEFI), systemd-stage-1 initrd, AMD pstate + microcode.
{ pkgs, ... }:
{
  boot.loader.systemd-boot = {
    enable = true;
    # 1G ESP + large CachyOS LTO kernels -> keep a modest number of generations.
    configurationLimit = 5;
  };
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot";

  # systemd in initrd: ZFS passphrase prompt + impermanence rollback run as
  # proper systemd units in early boot.
  boot.initrd.systemd.enable = true;

  # AMD Ryzen AI Max+ 395 (Strix Halo, Zen 5): active pstate (EPP) + microcode.
  boot.kernelParams = [ "amd_pstate=active" ];
  hardware.cpu.amd.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;
}
