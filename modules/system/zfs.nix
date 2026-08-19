# ZFS host config + periodic maintenance.
# NOTE: the ZFS *package* is wired to the CachyOS overlay module
# (config.boot.kernelPackages.zfs_cachyos) in modules/system/kernel.nix.
{ ... }:
{
  # NOTE: networking.hostId is HOST-SPECIFIC (ZFS uses it as the pool's
  # last-imported owner id) and is set per host in each hosts/*/default.nix --
  # NOT here, or both machines would share one id.

  boot.supportedFilesystems.zfs = true;

  # Prompt for the native-encryption passphrase at boot (systemd initrd unit).
  boot.zfs.requestEncryptionCredentials = true;

  # Force-import the root pool even when last-accessed-by hostid doesn't match.
  # Safety net for hostid drift (e.g. booting a LiveCD between sessions); on a
  # single-host workstation the multi-host concurrent-access risk does not apply.
  boot.zfs.forceImportRoot = true;

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
