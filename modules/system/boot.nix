# Boot: systemd-boot (UEFI) with a MIRRORED ESP, systemd-stage-1 initrd,
# AMD pstate + microcode.
{ pkgs, ... }:
{
  boot.loader.systemd-boot = {
    enable = true;
    # 1G ESP + large CachyOS LTO kernels -> keep a modest number of generations.
    configurationLimit = 5;
    # Keep the secondary ESP (/boot-fallback on the other NVMe) byte-for-byte in
    # sync after every bootloader install, so the box still boots if the primary
    # NVMe dies. (The ZFS pool is a non-redundant stripe, but the ESPs are not.)
    extraInstallCommands = ''
      ${pkgs.rsync}/bin/rsync -a --delete /boot/EFI/ /boot-fallback/EFI/
      ${pkgs.rsync}/bin/rsync -a --delete /boot/loader/ /boot-fallback/loader/
    '';
  };
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot";

  # systemd in initrd: ZFS passphrase prompt + impermanence rollback run as
  # proper systemd units in early boot.
  boot.initrd.systemd.enable = true;

  # AMD Ryzen 9 9950X: active pstate (EPP) governor + microcode updates.
  boot.kernelParams = [ "amd_pstate=active" ];
  hardware.cpu.amd.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;
}
