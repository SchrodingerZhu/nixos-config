# niri configuration (via niri-flake's programs.niri.settings DSL).
#
# We OWN all keybinds here (DMS preset binds are disabled in dms.nix), so there
# is no Mod+Space conflict: Mod+Space launches vicinae, as required.
# DMS itself is started by its systemd user service (see dms.nix), so we do NOT
# spawn it here. KeePassXC and fcitx5 are spawned at startup.
{ config, pkgs, ... }:
{
  programs.niri.package = pkgs.niri-unstable;

  programs.niri.settings = {
    prefer-no-csd = true;

    spawn-at-startup = [
      { command = [ "keepassxc" ]; } # SSH agent + secret store
      {
        command = [
          "fcitx5"
          "-d"
          "-r"
        ];
      } # CJK input method
    ];

    # XWayland via niri's built-in xwayland-satellite integration: niri spawns
    # and supervises the satellite, assigns the DISPLAY, and propagates it to
    # spawned children AND the systemd-user / D-Bus activation environment. That
    # is what the old manual `spawn-at-startup` + `environment.DISPLAY = ":12"`
    # approach could NOT do (it only reached niri's direct children), which is
    # why DISPLAY wasn't set automatically. Needs unstable niri + unstable
    # xwayland-satellite (both from niri-flake).
    xwayland-satellite = {
      enable = true;
      path = pkgs.lib.getExe pkgs.xwayland-satellite-unstable;
    };

    environment = {
      # Hint toolkits toward the Wayland/fcitx5 path.
      QT_QPA_PLATFORM = "wayland";
      GDK_BACKEND = "wayland";
    };

    binds = with config.lib.niri.actions; {
      # ---- REQUIRED: vicinae launcher on Mod+Space ----
      "Mod+Space".action = spawn "vicinae" "vicinae://toggle";

      # Apps
      "Mod+Return".action = spawn "wezterm";
      "Mod+T".action = spawn "wezterm";
      "Mod+B".action = spawn "zen-twilight";

      # Window management
      "Mod+Q".action = close-window;
      "Mod+F".action = maximize-column;
      "Mod+Shift+F".action = fullscreen-window;
      "Mod+W".action = toggle-column-tabbed-display;

      # Resize (runtime finetuning of window/column sizes)
      "Mod+R".action = switch-preset-column-width;
      "Mod+Shift+R".action = switch-preset-window-height;
      "Mod+Ctrl+R".action = reset-window-height;
      "Mod+Ctrl+F".action = expand-column-to-available-width;
      "Mod+Minus".action = set-column-width "-10%";
      "Mod+Equal".action = set-column-width "+10%";
      "Mod+Shift+Minus".action = set-window-height "-10%";
      "Mod+Shift+Equal".action = set-window-height "+10%";

      # Focus
      "Mod+Left".action = focus-column-left;
      "Mod+Right".action = focus-column-right;
      "Mod+Up".action = focus-window-up;
      "Mod+Down".action = focus-window-down;
      "Mod+H".action = focus-column-left;
      "Mod+L".action = focus-column-right;
      "Mod+K".action = focus-window-up;
      "Mod+J".action = focus-window-down;

      # Move
      "Mod+Shift+Left".action = move-column-left;
      "Mod+Shift+Right".action = move-column-right;
      "Mod+Shift+Up".action = move-window-up;
      "Mod+Shift+Down".action = move-window-down;

      # Workspaces
      "Mod+1".action = focus-workspace 1;
      "Mod+2".action = focus-workspace 2;
      "Mod+3".action = focus-workspace 3;
      "Mod+4".action = focus-workspace 4;
      "Mod+5".action = focus-workspace 5;
      "Mod+6".action = focus-workspace 6;
      "Mod+7".action = focus-workspace 7;
      "Mod+8".action = focus-workspace 8;
      "Mod+9".action = focus-workspace 9;

      # Media / brightness keys (PipeWire + brightnessctl)
      "XF86AudioRaiseVolume".action = spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%+";
      "XF86AudioLowerVolume".action = spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-";
      "XF86AudioMute".action = spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle";
      "XF86MonBrightnessUp".action = spawn "brightnessctl" "set" "5%+";
      "XF86MonBrightnessDown".action = spawn "brightnessctl" "set" "5%-";

      # Session
      "Mod+Shift+Slash".action = show-hotkey-overlay;
      "Mod+Shift+E".action = quit;
    };
  };
}
