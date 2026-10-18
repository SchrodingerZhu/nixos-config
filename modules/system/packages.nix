# CLI/TUI userland, installed system-wide so every account (including the
# guest, see guest.nix) gets the same toolset. GUI applications are per-user
# in modules/home/packages.nix.
#
# distrobox is just the CLI wrapper -- its container backend (rootless podman)
# and the sub-uid/gid ranges are configured at the system level
# (see the host's default.nix).
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    python3
    distrobox
    claude-code
    codex
    bubblewrap # bwrap for the codex and ChatGPT sandboxes
    gh # GitHub CLI
    gnupg
    waypipe # Forward Wayland applications over SSH.

    # System monitors
    fastfetch
    btop
    htop
    nvtopPackages.amd # AMD Radeon 8060S (RDNA 3.5) iGPU

    # Dev tools (direnv itself is configured in modules/home/direnv.nix)
    texliveFull # full TeX Live (all packages) -- several GB
    ripgrep
    sox # audio conversion / recording CLI (sox, play, rec)
    cloudflared # Cloudflare Tunnel client: `cloudflared access ssh`
  ];
}
