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

  # rclone >= 1.75.1 is REQUIRED for the Proton Drive backend: 1.75.0 (the
  # current nixpkgs pin) "corrupts uploads after a retried upload error" and
  # writes files "not readable in the Proton apps" (both fixed in 1.75.1,
  # 2026-09-04). Retried uploads are the norm against Proton's storage nodes,
  # so 1.75.0 is unusable for backups. Drop this override once nixpkgs >= 1.75.1.
  rcloneProton = pkgs.rclone.overrideAttrs (old: {
    version = "1.75.1";
    src = pkgs.fetchFromGitHub {
      owner = "rclone";
      repo = "rclone";
      tag = "v1.75.1";
      hash = "sha256-d2WGx9Rplf7nrUZbYRYJffPKB7Fk0OZc9o3TUVoaG50=";
    };
    vendorHash = "sha256-3HkOymYmr3JFG/Cs8GKHImRioQaHbiI3MEJR1ZPhbu8=";
  });

  # nixpkgs wraps the restic binary with ITS rclone prepended to PATH
  # (postInstall: wrapProgram --prefix PATH), which silently overrides the
  # unit's `path`. Rebuild restic against the pinned rclone instead.
  resticProton = pkgs.restic.override { rclone = rcloneProton; };

  unit = "restic-backups-proton";
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
    package = resticProton;
    initialize = true; # `restic init` on first run
    inhibitsSleep = true; # laptop: don't suspend mid-upload
    # One "[elapsed] N% done, X/Y GiB, ETA" status line in the journal every
    # 30 s (restic only shows progress on a TTY otherwise). Needs the
    # pre-scan for the percentage/ETA, so --no-scan is deliberately NOT set.
    progressFps = 1.0 / 30;

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
    # restic shells out to `rclone serve restic --stdio`; belt and braces next
    # to the wrapper above (the wrapper's --prefix is what actually decides).
    path = [ rcloneProton ];
    # Cap the Restart= loop: the initial start + 2 retries per 6 h window, then
    # the unit stays failed until the next timer elapse. Without this a
    # PERSISTENT failure (e.g. `check` finding damaged packs, which no retry
    # can fix) re-runs the whole chain -- backup included -- every 15 min for
    # ever, minting a snapshot and downloading ~1 GiB of check data each time
    # (seen 2026-09-08: 37 restarts overnight). After the cap trips,
    # `systemctl reset-failed restic-backups-proton` re-arms manual starts.
    startLimitIntervalSec = 6 * 3600;
    startLimitBurst = 3;
    serviceConfig = {
      # Proton's storage nodes fail often enough that a whole run can die after
      # restic/rclone exhaust their own retries. Retry the run itself (restic
      # resumes from the uploaded packs); on-failure is the only Restart= mode
      # valid for a oneshot. A hang (no error) is handled by the watchdog below.
      Restart = "on-failure";
      RestartSec = "15min";
      # Uploads bypass the ProtonVPN tunnel: sockets with gid `novpn` are marked
      # direct by the split-tunnel nftables chain (modules/system/vpn.nix). The
      # service still runs as root; only its primary group changes.
      Group = "novpn";
      Nice = 10;
      IOSchedulingClass = "best-effort";
      IOSchedulingPriority = 7;
    };
  };

  # ---- stall watchdog ------------------------------------------------------
  # rclone's Proton client has been seen to hang silently (no request in
  # flight, no error, no retry) for good; no timeout in restic or rclone covers
  # that. Every 5 min compare the unit's IP byte counters (in+out, so the
  # download-heavy `check` phase counts too) with the previous sample; after 3
  # unchanged samples (15 min) while the main process is running, restart the
  # unit. Uploaded packs are kept, so a restart costs a local re-hash only.
  systemd.services."${unit}-watchdog" = {
    description = "Restart ${unit} if its network traffic has stalled";
    serviceConfig.Type = "oneshot";
    path = [
      pkgs.systemd
      pkgs.coreutils
    ];
    script = ''
      state=/run/${unit}-watchdog
      mkdir -p "$state"
      sub=$(systemctl show ${unit} -p SubState --value)
      if [ "$sub" != "start" ]; then
        rm -f "$state/last" "$state/strikes"; exit 0   # not in the main phase
      fi
      inv=$(systemctl show ${unit} -p InvocationID --value)
      in=$(systemctl show ${unit} -p IPIngressBytes --value)
      out=$(systemctl show ${unit} -p IPEgressBytes --value)
      cur="$inv $((in + out))"
      last=$(cat "$state/last" 2>/dev/null || true)
      strikes=$(cat "$state/strikes" 2>/dev/null || echo 0)
      if [ "$cur" = "$last" ]; then strikes=$((strikes + 1)); else strikes=0; fi
      echo "$cur" > "$state/last"; echo "$strikes" > "$state/strikes"
      if [ "$strikes" -ge 3 ]; then
        echo "no traffic for $((strikes * 5)) min -> restarting ${unit}"
        rm -f "$state/last" "$state/strikes"
        systemctl restart --no-block ${unit}
      fi
    '';
  };
  systemd.timers."${unit}-watchdog" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "5min";
      AccuracySec = "30s";
    };
  };
}
