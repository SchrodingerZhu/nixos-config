# CLI/TUI userland, installed system-wide so every account (including the
# guest, see guest.nix) gets the same toolset. GUI applications are per-user
# in modules/home/packages.nix.
#
# distrobox is just the CLI wrapper -- its container backend (rootless podman)
# and the sub-uid/gid ranges are configured at the system level
# (see the host's default.nix).
{ pkgs, lib, ... }:
{
  nixpkgs.overlays = [
    (final: prev: {
      # Prefer nixpkgs once it catches up with the local package.
      google-colab-cli =
        let
          local = final.callPackage ../../packages/google-colab-cli.nix { };
        in
        if prev ? google-colab-cli && lib.versionAtLeast prev.google-colab-cli.version local.version then
          prev.google-colab-cli
        else
          local;
    })
  ];

  environment.systemPackages = with pkgs; [
    python3
    distrobox
    claude-code
    codex
    antigravity-cli
    google-colab-cli
    bubblewrap # bwrap for the codex and ChatGPT sandboxes
    gh # GitHub CLI
    gnupg
    waypipe # Forward Wayland applications over SSH.
    tmux
    zellij

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
