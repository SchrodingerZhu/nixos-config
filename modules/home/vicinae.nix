# vicinae launcher — runs as a user service so Mod+Space (bound in niri.nix) is
# an instant toggle.
{ pkgs, ... }:
{
  programs.vicinae = {
    enable = true;
    # Use system libraries so the launcher can load the current graphics driver.
    package = pkgs.vicinae;
    systemd = {
      enable = true;
      autoStart = true;
    };
  };
}
