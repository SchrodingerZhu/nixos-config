# General userland packages (not tied to a specific app module).
#
# Persistence note: these are declared in the flake, so they rebuild into /nix
# (a persistent dataset) on every switch. Any runtime data they create lives
# under $HOME (the safe/home dataset) and survives the ephemeral-root wipe with
# no extra environment.persistence entries.
#
# distrobox is just the CLI wrapper — its container backend (rootless podman)
# and the sub-uid/gid ranges are configured at the system level
# (see hosts/workstation/default.nix). steam is likewise enabled there via
# programs.steam, NOT here, so it gets the FHS env + controller udev rules.
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    python3
    distrobox
    claude-code
    vscode # Insiders isn't packaged in nixpkgs; using stable.
    gh # GitHub CLI
    obs-studio # screen capture via the gnome ScreenCast portal (see xdg.portal)
    taterclient-ddnet # DDNet client
    telegram-desktop
    vesktop # Discord client (better Wayland/screenshare support than official)
  ];
}
