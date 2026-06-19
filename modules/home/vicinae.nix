# vicinae launcher — runs as a user service so Mod+Space (bound in niri.nix) is
# an instant toggle.
{ ... }:
{
  services.vicinae = {
    enable = true;
    systemd = {
      enable = true;
      autoStart = true;
    };
  };
}
