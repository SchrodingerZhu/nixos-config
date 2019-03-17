{ config, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];
#  systemd.services.nix-daemon.environment = {
#    https_proxy = "socks5://127.0.0.1:1080";
#  };
#  unstable = import <unstable> {
#        config = {
#            allowUnfree = true;
#            allowUnsupportedSystem = true;
#            allowBroken = true;
#        };
#  };

  ### Services
  
  services.fstrim = {
    enable = true;
    interval = "tuesday";  
  };

  nix.gc = {
    automatic = true;
    dates = "thursday";
    options = "--delete-older-than 8d";
  };

  powerManagement.powertop.enable = true;

  services.printing.enable = true;

  # Don't start a getty behind my graphical login
  systemd.services."autovt@tty1".enable = false;

  ### Random software

  nixpkgs.overlays = [ (self: super:
    { sarasa-gothic = self.callPackage ./sarasa-gothic.nix {}; }) ];

  environment.systemPackages = with pkgs; [
    fcitx-configtool wget emacs shadowsocks-libev proxychains elixir_1_8 erlangR21 jdk11 dotty fstar gcc8 clang_7 firefox git python37Full sbt scala_2_12 vscode jetbrains.clion jetbrains.idea-ultimate jetbrains.pycharm-professional qt5Full qtcreator julia deepin.deepin-gtk-theme neofetch file lolcat commonsCompress
    # Password manager for KDE
    kdeFrameworks.kwallet
    kdeApplications.kwalletmanager
    kwalletcli

    # Allow automatic unlocking of kwallet if the same password. This seems to
    # work without installing kwallet-pam.
    #kwallet-pam

    # ssh-add prompts a user for a passphrase using KDE. Not sure if it is used
    # by anything? ssh-add just asks passphrase on the console.
    #ksshaskpass

    # Archives (e.g., tar.gz and zip)
    ark

    # GPG manager for KDE
    kgpg
    # This is needed for graphical dialogs used to enter GPG passphrases
    pinentry_qt5

    kdeplasma-addons

    # Screenshots
    kdeApplications.spectacle

    # Bluetooth
    bluedevil

    # Text editor
    kate

    # Torrenting
    ktorrent

    # Connect desktop and phone
    kdeconnect

    # Drop-down terminal
    yakuake

    # Printing and scanning
    kdeApplications.print-manager
    simple-scan

    # Document readers
    okular

    # Browsers
    firefox
    chromium

    # Email
    #kmail
    thunderbird

    # Office suit
    libreoffice

    # Photo/image editor
    gwenview
    gimp
    #gimpPlugins.resynthesizer
    #gimpPlugins.ufraw
    digikam5

    # Media player
    vlc

    # KDE apps
    kdeFrameworks.kconfig
    kdeFrameworks.kconfigwidgets
    konsole
    dolphin
    kdeApplications.dolphin-plugins
];
  programs.mtr.enable = true;

  nix.extraOptions = ''
    keep-outputs = true
    keep-derivations = true
  '';

  programs.ssh = {
    startAgent = true;
  };

  ### Graphical

  services.xserver = {
    enable = true;
    layout = "us";

    libinput.enable = true;

    displayManager.sddm = {
      enable = true;
      extraConfig = ''
        [X11]
        ServerArguments=-nolisten tcp -dpi 200
        MinimumVT=1
      '';
    };

    desktopManager.plasma5.enable = true;

    xkbOptions = "terminate:ctrl_alt_bksp,caps:ctrl_modifier";
  };

  i18n.inputMethod = {
    enabled = "fcitx";
    fcitx.engines = with pkgs.fcitx-engines; [ libpinyin rime ];
  };

  fonts.fonts = with pkgs; [
    sarasa-gothic
  ];

  fonts.enableFontDir = true;

  fonts.fontconfig.defaultFonts = {
    monospace = [ "Sarasa Mono SC" ];
    sansSerif = [ "Sarasa UI SC" ];
    serif = [ "Sarasa UI SC" ];
  };

  
  ### Boot and kernel
  boot.kernelPackages = pkgs.linuxPackages_latest_hardened;
  boot.loader.systemd-boot.enable = true;
  boot.loader.timeout = 10;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelParams = [ "i915.fastboot=1" "quiet" "acpi_osi=!" "acpi=\"windows2009\""];

  boot.extraModulePackages = [ pkgs.linuxPackages_latest_hardened.nvidia_x11_beta pkgs.linuxPackages_latest_hardened.perf];

  boot.kernel.sysctl = {
    "vm.swappiness" = 5;
    "vm.vfs_cache_pressure" = 50;
  };
  
  hardware.cpu.intel.updateMicrocode = true;

  ### Networking

  networking.hostName = "homura";
  networking.networkmanager.enable = true;

  networking.firewall.allowedTCPPorts = [ 12345 ];
  networking.firewall.logRefusedConnections = false;

  ### Users
  users.defaultUserShell = pkgs.fish;
  users.users.schrodinger = {
    isNormalUser = true;
    useDefaultShell = true;
    uid = 1000;
    extraGroups = [ "wheel" "vboxusers" "docker" ];
  };

  ### Misc

  boot.earlyVconsoleSetup = true;

  i18n.consolePackages = [ pkgs.terminus_font ];
  i18n.consoleFont = "ter-132n";
  i18n.consoleKeyMap = "us";
  i18n.defaultLocale = "en_US.UTF-8";

  time.timeZone = "Asia/Shanghai";

  sound.enable = true;
  hardware.pulseaudio.enable = true;

  nix.trustedUsers = [ "root" "schrodinger" ];

  # This value determines the NixOS release with which your system is to be
  # compatible, in order to avoid breaking some software such as database
  # servers. You should change this only after NixOS release notes say you
  # should.
  services.flatpak.enable = true;
  programs.fish.enable = true;
  #programs.zsh.autosuggestions.enable = true;
  hardware.bumblebee.enable = true;
  hardware.bumblebee.connectDisplay = true;
  system.autoUpgrade.enable = true;
  system.autoUpgrade.channel = https://nixos.org/channels/nixos-unstable-small;
  nixpkgs.config.allowUnsupportedSystem = true; 
  nixpkgs.config.allowBroken = true; 
  nixpkgs.config.allowUnfree = true;
  virtualisation.docker.enable = true;
  services.emacs.install = true;
  services.emacs.enable = true;
  services.emacs.defaultEditor = true;
  system.stateVersion = "19.09"; # Did you read the comment?
}
