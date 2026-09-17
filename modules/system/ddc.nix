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

      # sync with latest upstream firmware
      linux-firmware =
        if lib.versionOlder prev.linux-firmware.version "20260916" then
          prev.linux-firmware.overrideAttrs (_: {
            version = "20260916";
            src = final.fetchFromGitLab {
              owner = "kernel-firmware";
              repo = "linux-firmware";
              tag = "20260916";
              hash = "sha256-VbDTRN/i+a1BrKnDtdDFxanp3BQujBhe9CyWay9GTXY=";
            };
          })
        else
          prev.linux-firmware;

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
