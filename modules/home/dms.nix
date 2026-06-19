# DankMaterialShell (DMS) — follows the official NixOS flake doc, with the full
# recommended feature set enabled. DMS provides notifications + wallpaper, so we
# do NOT run mako/swaybg.
#
# Startup: DMS's own systemd user service (systemd.enable = true). Therefore
# niri.enableSpawn = false (avoids two DMS instances).
# Keybinds: we manage them ourselves in niri.nix (enableKeybinds = false), so
# vicinae keeps Mod+Space. niri.includes pulls only the VISUAL bits (colors,
# layout, outputs, wpblur) from DMS — not binds — so there's no key conflict.
{ pkgs, ... }:
{
  programs.dank-material-shell = {
    enable = true;

    systemd = {
      enable = true;
      restartIfChanged = true;
    };

    # Recommended feature toggles (companion packages provided below).
    enableSystemMonitoring = true; # dgop
    enableVPN = true;
    enableDynamicTheming = true; # matugen
    enableAudioWavelength = true; # cava
    enableCalendarEvents = true; # khal
    enableClipboardPaste = true; # wtype

    niri = {
      enableKeybinds = false; # we own keybinds (vicinae must keep Mod+Space)
      enableSpawn = false; # started via systemd.enable instead
      includes = {
        enable = true;
        override = true;
        originalFileName = "hm";
        # Visual integration only — NOT "binds"/"alttab".
        filesToInclude = [
          "colors"
          "layout"
          "outputs"
          "wpblur"
        ];
      };
    };
  };

  # Companion userland the toggles expect, plus common desktop helpers.
  home.packages = with pkgs; [
    matugen # dynamic theming
    cava # audio wavelength
    khal # calendar events
    wtype # clipboard paste
    brightnessctl # brightness keys
    playerctl # media keys
    wl-clipboard # clipboard
    cliphist # clipboard history
  ];
}
