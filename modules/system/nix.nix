# Shared Nix settings and LAN binary cache.
{ inputs, pkgs, ... }:
let
  # TLS trust is configured in sccache.nix.
  # zstd keeps compression overhead low for LAN uploads.
  nixCacheUrl = "s3://nix-cache?endpoint=192.168.0.92:9000&scheme=https&region=auto&compression=zstd";
  awsCreds = "/persist/secrets/sccache/aws-credentials";

  # Cache upload failures do not fail local builds.
  postBuildPush = pkgs.writeShellScript "nix-cache-push" ''
    export AWS_SHARED_CREDENTIALS_FILE=${awsCreds}
    ${pkgs.coreutils}/bin/timeout 120 \
      nix --extra-experimental-features 'nix-command flakes' \
        copy --to '${nixCacheUrl}' $OUT_PATHS 2>/dev/null || true
  '';
in
{
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
      "ca-derivations"
    ];
    trusted-users = [ "root" "schrodingerzy" ];

    substituters = [
      # Prefer the LAN cache, with public caches as fallbacks.
      "${nixCacheUrl}&priority=30"
      "https://cache.nixos.org"
      "https://attic.xuyh0120.win/lantian" # CachyOS kernel + zfs_cachyos
      "https://niri.cachix.org" # niri
      "https://vicinae.cachix.org" # vicinae launcher
      "https://cache.numtide.com" # claude-code, codex (numtide/llm-agents.nix)
    ];
    trusted-public-keys = [
      "rustfs-nix-1:vljOeYpwlqy6/6YgzAJANzN0DzXNCXbCYtOcWNNMxs8=" # LAN SeaweedFS cache
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
      "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="
      "vicinae.cachix.org-1:1kDrfienkGHPYbkpNj1mWTr7Fm1+zcenzgTizIcI3oc="
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    ];

    # Both hosts use the same key to sign local builds.
    secret-key-files = [ "/persist/secrets/nix-cache-key.pem" ];
    connect-timeout = 5;
    post-build-hook = postBuildPush;
  };

  # The Nix daemon needs the shared S3 credentials.
  systemd.services.nix-daemon.environment.AWS_SHARED_CREDENTIALS_FILE = awsCreds;

  # Root accesses the store directly and needs default AWS credentials.
  # Recreate the credentials link after each ephemeral-root reset.
  systemd.tmpfiles.rules = [
    "d /root/.aws 0700 root root -"
    "L+ /root/.aws/credentials - - - - ${awsCreds}"
  ];

  # Unfree allowed globally at the system level (home-manager uses
  # useGlobalPkgs, so it inherits this).
  nixpkgs.config.allowUnfree = true;

  # The flake repo is owned by the user, but `sudo nixos-rebuild` evaluates as
  # root: libgit2 refuses "dubious ownership" unless the path is marked safe.
  # Root's ~/.gitconfig is wiped every boot (ephemeral root), so set it in the
  # system-wide /etc/gitconfig instead.
  environment.etc."gitconfig".text = ''
    [safe]
    	directory = /persist/etc/nixos
  '';

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
