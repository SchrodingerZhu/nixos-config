# Off-site backup to Proton Drive: restic over rclone's `protondrive` backend.
#
# Twice a week (Mon + Thu 03:00) a fresh ZFS snapshot (@restic) of the two
# data-bearing datasets is taken, restic reads the FROZEN view through
# /<mnt>/.zfs/snapshot/restic, and the snapshot is destroyed afterwards
# (postStop -> also on failure). Everything is chunked, deduplicated, zstd
# compressed and AES-256 encrypted CLIENT-SIDE by restic before rclone uploads
# it, so Proton only ever holds ciphertext under a key we own -- independent of
# Proton's own E2EE.
#
# One repository per host: rclone:protondrive:backups/restic/<hostname>.
#
# Secrets (in /persist/secrets, OUTSIDE this repo, mode 0600):
#   rclone.conf      -- [protondrive] remote: Proton username, obscured password,
#                       otp_secret_key (TOTP seed -> unattended re-login), plus
#                       the client_* session tokens rclone caches after login.
#                       Must stay WRITABLE: rclone refreshes those tokens in place.
#   restic-password  -- repository key. ALSO keep a copy in KeePassXC: the backup
#                       contains /persist/secrets itself, so after a total disk
#                       loss this file is only recoverable WITH this password.
#
# Bootstrap (once per Proton account, already done): log into Proton Drive in a
# browser so the Drive keys exist, then `rclone config create protondrive
# protondrive username=... password=... otp_secret_key=... --obscure` and
# `rclone lsd protondrive:` to verify.
#
# Ops:  restic-proton snapshots            # wrapper with repo/password/rclone env preset
#       restic-proton restore latest:/home/.zfs/snapshot/restic --target /home
#       systemctl start restic-backups-proton   # run now (first seed takes days)
#
# Known limits of the rclone protondrive backend: beta, reverse-engineered API,
# uploads run at single-digit to low-tens MB/s. Fine for a nightly off-site
# copy, not for interactive use.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  zfs = lib.getExe' config.boot.zfs.package "zfs";
  datasets = [
    "rpool/safe/persist"
    "rpool/safe/home"
  ];
  snapName = "restic";
in
{
  services.restic.backups.proton = {
    repository = "rclone:protondrive:backups/restic/${config.networking.hostName}";
    passwordFile = "/persist/secrets/restic-password";
    rcloneConfigFile = "/persist/secrets/rclone.conf";
    initialize = true; # `restic init` on first run
    inhibitsSleep = true; # laptop: don't suspend mid-upload
    # One "[elapsed] N% done, X/Y GiB, ETA" status line in the journal every
    # 10 minutes (restic only shows progress on a TTY otherwise). Needs the
    # pre-scan for the percentage/ETA, so --no-scan is deliberately NOT set.
    progressFps = 1.0 / 600;

    # Frozen views of the datasets (see prepare/cleanup below).
    paths = [
      "/persist/.zfs/snapshot/${snapName}"
      "/home/.zfs/snapshot/${snapName}"
    ];
    # Patterns without a leading "/" match any path suffix, i.e. under every
    # user's home. Re-downloadable or churny data only.
    exclude = [
      ".cache"
      ".local/share/Trash"
      ".local/share/Steam" # game library
      ".local/share/containers" # rootless podman / distrobox images
      ".cargo/registry"
      ".cargo/git"
      ".rustup"
      "node_modules"
    ];
    extraBackupArgs = [
      "--exclude-caches" # honours CACHEDIR.TAG (cargo target/, pip, etc.)
      "--compression max" # upload bandwidth is the bottleneck, not CPU
      "--pack-size 64" # fewer, larger objects -> fewer Proton API calls
    ];

    timerConfig = {
      OnCalendar = "Mon,Thu *-*-* 03:00:00";
      Persistent = true; # catch up after the box was off
      RandomizedDelaySec = "30m";
    };

    # Retention (applied after each backup); generous --max-unused limits
    # repack traffic against the slow backend.
    pruneOpts = [
      "--keep-within 14d"
      "--keep-weekly 8"
      "--keep-monthly 6"
      "--max-unused 25%%" # %% : literal % in a systemd ExecStart line
      "--pack-size 64"
    ];
    # Structural check every run + a 2% random sample of pack data read back,
    # so silent corruption on the remote side surfaces within weeks.
    runCheck = true;
    checkOpts = [ "--read-data-subset=2%%" ]; # %% as above

    rcloneOptions = {
      # An upload interrupted mid-flight leaves a "draft" on Proton Drive that
      # would otherwise make the retry fail with a name conflict.
      protondrive-replace-existing-draft = true;
    };

    # Fresh @restic snapshot of each dataset (dropping a stale one from a
    # crashed run first). Accessing .zfs/snapshot/<name> auto-mounts it.
    backupPrepareCommand = ''
      #!${pkgs.runtimeShell}
      set -eu
      for ds in ${lib.escapeShellArgs datasets}; do
        ${zfs} destroy "$ds@${snapName}" 2>/dev/null || true
        ${zfs} snapshot "$ds@${snapName}"
      done
    '';
    # Runs from postStop, i.e. also after a failed backup.
    backupCleanupCommand = ''
      #!${pkgs.runtimeShell}
      for ds in ${lib.escapeShellArgs datasets}; do
        mnt=$(${zfs} get -H -o value mountpoint "$ds")
        ${pkgs.util-linux}/bin/umount "$mnt/.zfs/snapshot/${snapName}" 2>/dev/null || true
        for i in 1 2 3 4 5; do
          ${zfs} destroy "$ds@${snapName}" 2>/dev/null && break
          sleep 2
        done
      done
    '';
  };

  systemd.services.restic-backups-proton = {
    # restic shells out to `rclone serve restic --stdio`; the module doesn't add it.
    path = [ pkgs.rclone ];
    serviceConfig = {
      # Uploads bypass the ProtonVPN tunnel: sockets with gid `novpn` are marked
      # direct by the split-tunnel nftables chain (modules/system/vpn.nix). The
      # service still runs as root; only its primary group changes.
      Group = "novpn";
      Nice = 10;
      IOSchedulingClass = "best-effort";
      IOSchedulingPriority = 7;
    };
  };
}
