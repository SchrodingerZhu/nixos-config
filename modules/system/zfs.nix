# ZFS host config + periodic maintenance.
# NOTE: the ZFS *package* is wired to the CachyOS overlay module
# (config.boot.kernelPackages.zfs_cachyos) in modules/system/kernel.nix.
{ ... }:
{
  # Unique host id required by ZFS (generated for this machine).
  networking.hostId = "d7d9d8b0";

  boot.supportedFilesystems.zfs = true;

  # Prompt for the native-encryption passphrase at boot (systemd initrd unit).
  boot.zfs.requestEncryptionCredentials = true;

  # Recommended (new default from 26.11): don't force-import a pool that wasn't
  # cleanly exported — reduces the risk of data loss on a stripe with no redundancy.
  boot.zfs.forceImportRoot = false;

  # Periodic maintenance, scheduled on DIFFERENT days so the NVMes are never
  # scrubbed and trimmed at the same time.
  services.zfs.autoScrub = {
    enable = true;
    interval = "Sun *-*-* 02:00:00"; # weekly, Sunday 02:00
  };
  services.zfs.trim = {
    enable = true;
    interval = "Wed *-*-* 03:00:00"; # weekly, Wednesday 03:00 (autotrim=on also set on the pool)
  };
}
