# schrodingerzy — NixOS workstation

AMD Ryzen 9 9950X (Zen 5, RDNA2 iGPU) workstation. Flake-based, tracking
`nixos-unstable`.

## Highlights

- **Storage:** two NVMe SSDs as a **non-redundant ZFS stripe** (`rpool`), native
  encryption (aes-256-gcm, passphrase at boot), `compression=zstd`,
  `dedup=blake3` (all datasets), `ashift=12`, `autotrim=on`.
- **Ephemeral root** (impermanence): `rpool/local/root` rolls back to `@blank`
  every boot via an initrd systemd service. Persistent datasets: `/nix`,
  `/home`, `/persist` + mirrored ESPs (`/boot` + `/boot-fallback`).
- **This config lives on `/persist`** (`/persist/etc/nixos`) and is bind-mounted
  to `/etc/nixos`, so it survives the root wipe. Secrets (WiFi PSK, password
  hashes) live under `/persist` **outside this repo**.
- **Kernel:** CachyOS `linuxPackages-cachyos-latest-lto-zen4` (pinned overlay) +
  `zfs_cachyos`; `amd_pstate=active` + microcode.
- **Desktop:** niri (Wayland) + DankMaterialShell, DankGreeter, vicinae launcher
  (`Mod+Space`), WezTerm (WebGpu), Zen Browser (Twilight, default), fcitx5.
- **Shell:** fish + atuin + starship. **Secrets/SSH:** KeePassXC (feeds a stable
  `ssh-agent` at `~/.ssh/agent.socket`).
- **Hardening:** native nftables firewall, Ananicy-cpp, systemd-oomd + zram,
  AppArmor.
- **Snapshots:** zrepl local snap+prune (home + persist).
- **Off-site backup:** restic -> rclone -> Proton Drive, Mon+Thu 03:00, one repo
  per host, client-side AES-256 + zstd (see below).

## Layout

- `flake.nix`
- `hosts/workstation/{default,disko,hardware}.nix`
- `modules/system/*` — boot, kernel, zfs, impermanence, nix, fonts, hardening,
  network, zrepl, backup-proton
- `modules/home/*` — niri, dms, wezterm, shell, browser, vicinae, keepassxc, ssh

## Rebuild

```bash
sudo nixos-rebuild switch --flake /etc/nixos#schrodingerzy
```

`/etc/nixos` is a bind mount of `/persist/etc/nixos` (this git repo).

## Off-site backup (Proton Drive)

`modules/system/backup-proton.nix`: `services.restic.backups.proton` on both
hosts. Each run snapshots `rpool/safe/{persist,home}@restic`, backs up the frozen
`.zfs/snapshot/restic` views (excluding `~/.cache`, Steam, podman images, cargo
registry, ...), prunes (14d / 8w / 6m), runs `restic check` on a 2% data sample,
then destroys the snapshot. Repository: `rclone:protondrive:backups/restic/<host>`.

Secrets live in `/persist/secrets` (0600, not in git):

- `rclone.conf` -- `[protondrive]` remote (username, obscured password,
  `otp_secret_key` for unattended TOTP; rclone caches `client_*` session tokens
  in place, so the file must stay writable).
- `restic-password` -- repository key. **Keep a copy in KeePassXC**: the backup
  contains `/persist/secrets` itself, so it is the one thing that must survive
  outside the machine.

```bash
restic-proton snapshots                        # wrapper with repo/creds preset
restic-proton restore latest:/home/.zfs/snapshot/restic --target /home
sudo systemctl start restic-backups-proton     # run now; first seed takes days
journalctl -fu restic-backups-proton
```

New host: copy both secret files over (strip `client_*` lines from `rclone.conf`
so the host does its own login), rebuild, start the unit once.
