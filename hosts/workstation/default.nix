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
    ../../modules/system/vpn.nix
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
        fcitx5-rime # Rime engine (configure schemas in ~/.local/share/fcitx5/rime)
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

    # The greeter's DEFAULT generated niri config emits a `debug {
    # keep-max-bpc-unchanged }` node that niri-unstable (our package) rejects,
    # which crash-loops greetd and drops you into a broken bare compositor with
    # no login UI. Supplying our own config makes the greeter asset take its
    # custom-config branch (which omits that node); it still appends the
    # quickshell-greeter spawn line itself. This is upstream's default config
    # verbatim, minus the offending debug block.
    compositor.customConfig = ''
      hotkey-overlay {
          skip-at-startup
      }

      environment {
          DMS_RUN_GREETER "1"
      }

      gestures {
         hot-corners {
           off
         }
      }

      layout {
        background-color "#000000"
      }
    '';
  };

  # Use DMS's built-in polkit agent; disable niri-flake's to avoid a conflict.
  systemd.user.services.niri-flake-polkit.enable = false;

  # niri-flake unconditionally sets `services.gnome.gnome-keyring.enable = true`
  # whenever `programs.niri.enable` is on. We use KeePassXC as the secret store
  # and SSH agent, so force the whole thing off. Disabling this one option drops:
  # the gnome-keyring package, its org.freedesktop.secrets / org.gnome.keyring
  # D-Bus services, the Secret xdg-portal, the cap_ipc_lock setcap wrapper, and
  # the PAM `login` hook that spawns `gnome-keyring-daemon --login` at session start.
  services.gnome.gnome-keyring.enable = lib.mkForce false;

  # --- AMD iGPU (RDNA2) graphics + Wayland portals ---
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
  xdg.portal = {
    enable = true;
    # gtk: file chooser, settings, app-chooser.
    # gnome: ScreenCast + Screenshot (PipeWire) — required for screen capture
    # under niri (e.g. OBS). niri-flake also pulls in xdg-desktop-portal-gnome;
    # it is listed explicitly here so the routing below is self-contained.
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
      pkgs.xdg-desktop-portal-gnome
    ];
    config.common = {
      default = [ "gtk" ];
      "org.freedesktop.impl.portal.ScreenCast" = [ "gnome" ];
      "org.freedesktop.impl.portal.Screenshot" = [ "gnome" ];
    };
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

  # --- Steam (system module: FHS env, controller udev rules, 32-bit libs) ---
  # Bare pkgs.steam in home.packages would miss this integration. The game
  # library lives in ~/.local/share/Steam (safe/home dataset) -> persists.
  programs.steam.enable = true;

  # --- Containers: rootless podman as the distrobox backend ---
  # Images/containers go to ~/.local/share/containers (safe/home) -> persist.
  virtualisation.podman.enable = true;

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
    # Rootless podman (distrobox) needs sub-uid/gid mappings; required here
    # because mutableUsers = false means they aren't allocated otherwise.
    autoSubUidGidRange = true;
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
