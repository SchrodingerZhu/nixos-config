# Nix daemon settings: flakes, unfree, pinned registry/nixPath, binary caches,
# weekly GC.
{ inputs, ... }:
{
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
      "ca-derivations"
    ];
    trusted-users = [ "root" "schrodingerzy" ];

    substituters = [
      "https://cache.nixos.org"
      "https://attic.xuyh0120.win/lantian" # CachyOS kernel + zfs_cachyos
      "https://niri.cachix.org" # niri
      "https://vicinae.cachix.org" # vicinae launcher
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
      "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="
      "vicinae.cachix.org-1:1kDrfienkGHPYbkpNj1mWTr7Fm1+zcenzgTizIcI3oc="
    ];
  };

  # Unfree allowed globally at the system level (home-manager uses
  # useGlobalPkgs, so it inherits this).
  nixpkgs.config.allowUnfree = true;

  # Make ad-hoc `nix shell nixpkgs#...` resolve to the SAME nixpkgs as the flake.
  nix.registry.nixpkgs.flake = inputs.nixpkgs;
  nix.nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];

  # Weekly GC + store optimisation.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
  nix.optimise.automatic = true;
}
