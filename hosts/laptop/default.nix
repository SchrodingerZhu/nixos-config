# Host assembly for "manifold" — ASUS ROG Flow Z13 (GZ302EA), Strix Halo laptop.
{ inputs, config, pkgs, lib, ... }:
{
  imports = [
    ./hardware.nix
    ./disko.nix
    inputs.disko.nixosModules.disko

    inputs.impermanence.nixosModules.impermanence
    inputs.home-manager.nixosModules.home-manager

    # niri (compositor) + DMS at the NixOS level.
    inputs.niri.nixosModules.niri
    inputs.dms.nixosModules.dank-material-shell

    # System modules (split by concern). NOTE: vpn.nix is intentionally NOT
    # imported on the laptop -- ProtonVPN is off on this branch.
    ../../modules/system/boot.nix
    ../../modules/system/kernel.nix
    ../../modules/system/zfs.nix
    ../../modules/system/impermanence.nix
    ../../modules/system/nix.nix
    ../../modules/system/fonts.nix
    ../../modules/system/hardening.nix
    ../../modules/system/network.nix
    ../../modules/system/sshd.nix
    ../../modules/system/cowrie.nix
    ../../modules/system/zrepl.nix
    ../../modules/system/laptop.nix
    ../../modules/system/ddc.nix
    ../../modules/system/ups-client.nix
    ../../modules/system/timezone.nix
  ];

  # --- Overlays: CachyOS kernel (pinned -> max attic cache hits), niri, vicinae ---
  nixpkgs.overlays = [
    inputs.nix-cachyos-kernel.overlays.pinned
    inputs.niri.overlays.niri
    inputs.vicinae.overlays.default
    # click-threading (khal -> vdirsyncer): pytest collects docs/conf.py which
    # imports the removed pkg_resources. Mirrors nixpkgs 1cb613d (2026-07-09);
    # drop once the flake pin includes it.
    (final: prev: {
      pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
        (pyfinal: pyprev: {
          click-threading = pyprev.click-threading.overridePythonAttrs (old: {
            preCheck = (old.preCheck or "") + ''
              rm -rf docs
            '';
          });
        })
      ];
    })
  ];

  # --- Identity / locale / time ---
  networking.hostName = "manifold";
  networking.hostId = "84502e96"; # ZFS pool owner id for THIS machine (do not reuse)
  # time.timeZone deliberately unset: automatic-timezoned owns it (modules/system/timezone.nix)
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
        fcitx5-rime
      ];
    };
  };

  # --- niri at the system level so DankGreeter can see it (latest from flake) ---
  programs.niri.enable = true;
  programs.niri.package = pkgs.niri-unstable;

  # DankGreeter under niri.
  services.displayManager.dms-greeter = {
    enable = true;
    compositor.name = "niri";
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

  systemd.user.services.niri-flake-polkit.enable = false;
  services.gnome.gnome-keyring.enable = lib.mkForce false;

  # --- AMD iGPU (Strix Halo / RDNA 3.5) graphics + Wayland portals ---
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
  xdg.portal = {
    enable = true;
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

  # --- Bluetooth ---
  hardware.bluetooth.enable = true;

  # --- Steam (system module: FHS env, controller udev rules, 32-bit libs) ---
  programs.steam.enable = true;

  # --- Containers: rootless podman as the distrobox backend ---
  virtualisation.podman.enable = true;

  # --- Users (passwords set interactively into /persist/secrets — see install notes) ---
  programs.fish.enable = true;
  programs.ssh.startAgent = false;

  users.mutableUsers = false;
  users.users.root.hashedPasswordFile = "/persist/secrets/root.hash";
  users.users.schrodingerzy = {
    isNormalUser = true;
    description = "schrodingerzy";
    extraGroups = [ "wheel" "networkmanager" "video" "audio" ];
    shell = pkgs.fish;
    hashedPasswordFile = "/persist/secrets/schrodingerzy.hash";
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

  system.stateVersion = "25.11";
}
