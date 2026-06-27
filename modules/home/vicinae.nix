# vicinae launcher — runs as a user service so Mod+Space (bound in niri.nix) is
# an instant toggle.
{ ... }:
{
  programs.vicinae = {
    enable = true;
    systemd = {
      enable = true;
      autoStart = true;
    };
  };
}
