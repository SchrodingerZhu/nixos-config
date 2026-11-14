# External display brightness controls.
{ pkgs, ... }:
{
  nixpkgs.overlays = [
    (final: prev: {
      lg-brightness = final.callPackage ../../packages/lg-brightness.nix { };
    })
  ];

  hardware.i2c.enable = true;
  users.users.schrodingerzy.extraGroups = [ "i2c" ];

  environment.systemPackages = [
    pkgs.ddcutil
    pkgs.lg-brightness
  ];
  services.udev.packages = [ pkgs.lg-brightness ];
}
