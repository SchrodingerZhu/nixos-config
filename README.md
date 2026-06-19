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

## Layout

- `flake.nix`
- `hosts/workstation/{default,disko,hardware}.nix`
- `modules/system/*` — boot, kernel, zfs, impermanence, nix, fonts, hardening,
  network, zrepl
- `modules/home/*` — niri, dms, wezterm, shell, browser, vicinae, keepassxc, ssh

## Rebuild

```bash
sudo nixos-rebuild switch --flake /etc/nixos#schrodingerzy
```

`/etc/nixos` is a bind mount of `/persist/etc/nixos` (this git repo).
