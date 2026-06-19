# home-manager config for schrodingerzy.
{ inputs, pkgs, ... }:
{
  imports = [
    # NOTE: niri-flake's home module (programs.niri) is auto-injected into
    # home-manager users by its NixOS module (inputs.niri.nixosModules.niri,
    # imported at the host level), so we must NOT import it again here.
    inputs.dms.homeModules.dank-material-shell
    inputs.dms.homeModules.niri
    inputs.vicinae.homeManagerModules.default
    inputs.zen-browser.homeModules.twilight

    ./niri.nix
    ./dms.nix
    ./wezterm.nix
    ./packages.nix
    ./shell.nix
    ./browser.nix
    ./vicinae.nix
    ./keepassxc.nix
    ./ssh.nix
  ];

  home.username = "schrodingerzy";
  home.homeDirectory = "/home/schrodingerzy";
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  # Wayland hint for Electron/Chromium apps under niri.
  home.sessionVariables.NIXOS_OZONE_WL = "1";
}
