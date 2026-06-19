# Host assembly for "schrodingerzy" — AMD Ryzen 9 9950X workstation.
{ inputs, config, pkgs, lib, ... }:
{
  imports = [
    ./hardware.nix
    ./disko.nix
    inputs.disko.nixosModules.disko

    inputs.impermanence.nixosModules.impermanence
    inputs.home-manager.nixosModules.home-manager

    # niri (compositor) + DMS at the NixOS level
    inputs.niri.nixosModules.niri
    inputs.dms.nixosModules.dank-material-shell

    # System modules (split by concern)
    ../../modules/system/boot.nix
    ../../modules/system/kernel.nix
    ../../modules/system/zfs.nix
    ../../modules/system/impermanence.nix
    ../../modules/system/nix.nix
    ../../modules/system/fonts.nix
    ../../modules/system/hardening.nix
    ../../modules/system/network.nix
    ../../modules/system/zrepl.nix
  ];

  # --- Overlays: CachyOS kernel (pinned -> max attic cache hits), niri, vicinae ---
  nixpkgs.overlays = [
    inputs.nix-cachyos-kernel.overlays.pinned
    inputs.niri.overlays.niri
    inputs.vicinae.overlays.default
  ];

  # --- Identity / locale / time ---
  networking.hostName = "schrodingerzy";
  time.timeZone = "America/Los_Angeles";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  # CJK input method (fcitx5 + Chinese), Wayland frontend for niri.
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      waylandFrontend = true;
      addons = with pkgs; [
        qt6Packages.fcitx5-chinese-addons
        fcitx5-gtk
        qt6Packages.fcitx5-configtool
      ];
    };
  };

  # --- niri at the system level so DankGreeter can see it (latest from flake) ---
  programs.niri.enable = true;
  programs.niri.package = pkgs.niri-unstable;

  # DankGreeter (in-tree nixpkgs module) running under niri.
  services.displayManager.dms-greeter = {
    enable = true;
    compositor.name = "niri";
  };

  # Use DMS's built-in polkit agent; disable niri-flake's to avoid a conflict.
  systemd.user.services.niri-flake-polkit.enable = false;

  # --- AMD iGPU (RDNA2) graphics + Wayland portals ---
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common.default = [ "gtk" ];
  };

  # --- Audio: PipeWire ---
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # --- Bluetooth (nice-to-have on a workstation) ---
  hardware.bluetooth.enable = true;

  # --- Users (passwords set interactively into /persist/secrets — see install notes) ---
  programs.fish.enable = true; # system-level: registered login shell
  programs.ssh.startAgent = false; # KeePassXC is the SSH agent

  users.mutableUsers = false; # passwords come from persistent hash files (survive the wipe)
  users.users.root.hashedPasswordFile = "/persist/secrets/root.hash";
  users.users.schrodingerzy = {
    isNormalUser = true;
    description = "schrodingerzy";
    extraGroups = [ "wheel" "networkmanager" "video" "audio" ];
    shell = pkgs.fish;
    hashedPasswordFile = "/persist/secrets/schrodingerzy.hash";
  };

  # --- home-manager ---
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs; };
    users.schrodingerzy = import ../../modules/home/default.nix;
  };

  environment.systemPackages = with pkgs; [
    git
    vim
    wget
    curl
  ];

  # Track nixos-unstable. stateVersion pinned to the install-time release.
  system.stateVersion = "25.11";
}
