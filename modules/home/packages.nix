# General userland packages (not tied to a specific app module).
#
# Persistence note: these are declared in the flake, so they rebuild into /nix
# (a persistent dataset) on every switch. Any runtime data they create lives
# under $HOME (the safe/home dataset) and survives the ephemeral-root wipe with
# no extra environment.persistence entries.
#
# distrobox is just the CLI wrapper -- its container backend (rootless podman)
# and the sub-uid/gid ranges are configured at the system level
# (see hosts/laptop/default.nix). steam is likewise enabled there via
# programs.steam, NOT here, so it gets the FHS env + controller udev rules.
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    python3
    distrobox
    claude-code
    codex
    vscode # Insiders isn't packaged in nixpkgs; using stable.
    gh # GitHub CLI
    obs-studio # screen capture via the gnome ScreenCast portal (see xdg.portal)
    taterclient-ddnet # DDNet
    telegram-desktop
    sone # native Linux desktop client for TIDAL
    vesktop # Discord Wayland-native client

    # System monitors
    fastfetch
    btop
    htop
    nvtopPackages.amd # AMD Radeon 8060S (RDNA 3.5) iGPU

    # Dev tools (direnv itself is configured in direnv.nix)
    texliveFull # full TeX Live (all packages) -- several GB
    ripgrep
  ];
}
