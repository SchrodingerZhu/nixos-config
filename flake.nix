{
  description = "schrodingerzy — AMD Ryzen 9 9950X NixOS workstation (ZFS stripe, ephemeral root, niri + DMS)";

  inputs = {
    # Track nixos-unstable throughout.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Pure module flake (no nixpkgs input to follow).
    impermanence.url = "github:nix-community/impermanence";

    # CachyOS kernel overlay, RELEASE branch (binary-cache backed).
    # IMPORTANT: do NOT override its nixpkgs (README mandate) — leave as-is.
    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";

    # niri compositor flake. NOT following nixpkgs -> keeps niri.cachix hits
    # (overriding nixpkgs would rebuild niri from source).
    niri.url = "github:sodiboo/niri-flake";

    # DankMaterialShell — doc recommends following nixpkgs.
    dms = {
      url = "github:AvengeMedia/DankMaterialShell/stable";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # vicinae launcher. NOT following nixpkgs -> keeps vicinae.cachix hits.
    vicinae.url = "github:vicinaehq/vicinae";

    # Zen Browser (community flake), Twilight channel.
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ self, nixpkgs, ... }:
    {
      nixosConfigurations.schrodingerzy = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [ ./hosts/workstation/default.nix ];
      };
    };
}
