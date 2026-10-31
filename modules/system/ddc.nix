# External display brightness controls.
{ pkgs, lib, ... }:
{
  nixpkgs.overlays = [
    (final: prev: {
      ddcutil =
        if lib.versionOlder prev.ddcutil.version "3.0.1" then
          prev.ddcutil.overrideAttrs (_: {
            version = "3.0.1";
            src = final.fetchurl {
              url = "https://www.ddcutil.com/tarballs/ddcutil-3.0.1.tar.gz";
              hash = "sha256-HIYtwmOqKV8j2o2aZpNIfUzYyXqRveqkcRyrKKM83W4=";
            };
          })
        else
          prev.ddcutil;

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
