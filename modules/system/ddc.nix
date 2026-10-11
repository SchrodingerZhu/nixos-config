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

      # Upstream snapshot includes the September 18 DCN 3.5.1 DMCUB update.
      # Return to Nixpkgs once its firmware release reaches this snapshot date.
      linux-firmware =
        if lib.versionOlder prev.linux-firmware.version "20261002" then
          prev.linux-firmware.overrideAttrs (_: {
            version = "20261002-unstable";
            src = final.fetchFromGitLab {
              owner = "kernel-firmware";
              repo = "linux-firmware";
              rev = "d947e4e8e314e9254a1242dc1a5d9cede2cce33d";
              hash = "sha256-NA14ixKXzmg68RmXvyEXaUPt2MzytvnigfPVIkh/J0g=";
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
