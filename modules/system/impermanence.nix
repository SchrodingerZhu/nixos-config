# Ephemeral root (impermanence): the root dataset is rolled back to its @blank
# snapshot on EVERY boot, in initrd, BEFORE the root fs is mounted. Anything
# that must survive lives on a persistent dataset and is bind-mounted back from
# /persist via the impermanence module.
#
# /home and /nix are full persistent datasets, so ALL user data already
# survives: ~/.ssh, ~/.zen (Zen profile), ~/.local/share/atuin (history),
# ~/.local/share/fish, the KeePassXC database, and the nix store. No per-user
# impermanence needed.
{ config, lib, ... }:
{
  # --- Wipe root to @blank every boot (systemd initrd unit) ---
  boot.initrd.systemd.services.rollback-root = {
    description = "Rollback rpool/local/root to its blank snapshot";
    wantedBy = [ "initrd.target" ];
    after = [ "zfs-import-rpool.service" ];
    requires = [ "zfs-import-rpool.service" ];
    before = [ "sysroot.mount" ];
    path = [ config.boot.zfs.package ];
    unitConfig.DefaultDependencies = "no";
    serviceConfig.Type = "oneshot";
    script = "zfs rollback -r rpool/local/root@blank";
  };

  # /persist must be mounted early so the bind mounts below have a source.
  fileSystems."/persist".neededForBoot = true;

  # --- Things that must survive the wipe, bind-mounted from /persist ---
  environment.persistence."/persist" = {
    enable = true;
    hideMounts = true;
    directories = [
      "/etc/nixos" # the flake config + its git repo (true home of /etc/nixos)
      "/etc/NetworkManager/system-connections" # WiFi profiles (secrets, mode 0600)
      "/var/log"
      "/var/lib/nixos" # stable uid/gid allocations
      "/var/lib/bluetooth"
      "/var/lib/zrepl" # zrepl snapshot-job state
      "/var/lib/fcitx5" # input-method state
    ];
    files = [
      "/etc/machine-id" # stable machine-id for journald continuity
    ];
  };
}
