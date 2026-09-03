# Nix daemon settings: flakes, unfree, pinned registry/nixPath, binary caches,
# weekly GC, and the LAN binary cache on the workstation's rustfs.
{ inputs, pkgs, ... }:
let
  # LAN binary cache in the workstation's rustfs (see modules/system/rustfs.nix).
  # TLS trust comes from the committed CA (security.pki in sccache.nix ->
  # NIX_SSL_CERT_FILE); credentials are the shared rustfs pair.
  # compression=zstd: the default is single-threaded xz, which pegs one core
  # per NAR and made pushes crawl; zstd is fast and plenty for a LAN cache.
  nixCacheUrl = "s3://nix-cache?endpoint=192.168.0.92:9000&scheme=https&region=auto&compression=zstd";
  awsCreds = "/persist/secrets/sccache/aws-credentials";

  # Auto-push everything built locally; rustfs down => skip silently (|| true
  # + timeout) so builds are never blocked by the cache being unreachable.
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
      # LAN rustfs cache first (priority beats cache.nixos.org's 40); with the
      # 5s connect-timeout an unreachable cache degrades to a warning, never
      # an error — safe when manifold roams off the LAN.
      "${nixCacheUrl}&priority=30"
      "https://cache.nixos.org"
      "https://attic.xuyh0120.win/lantian" # CachyOS kernel + zfs_cachyos
      "https://niri.cachix.org" # niri
      "https://vicinae.cachix.org" # vicinae launcher
      "https://claude-code.cachix.org" # claude-code (sadjow/claude-code-nix)
    ];
    trusted-public-keys = [
      "rustfs-nix-1:vljOeYpwlqy6/6YgzAJANzN0DzXNCXbCYtOcWNNMxs8=" # LAN rustfs cache
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
      "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="
      "vicinae.cachix.org-1:1kDrfienkGHPYbkpNj1mWTr7Fm1+zcenzgTizIcI3oc="
      "claude-code.cachix.org-1:YeXf2aNu7UTX8Vwrze0za1WEDS+4DuI2kVeWEE4fsRk="
    ];

    # Sign local builds so both machines accept each other's pushes.
    # Key NOT in git: /persist/secrets/nix-cache-key.pem (same pair on both).
    secret-key-files = [ "/persist/secrets/nix-cache-key.pem" ];
    connect-timeout = 5;
    post-build-hook = postBuildPush;
  };

  # The daemon does the substitution/pushing -> it needs the S3 credentials.
  systemd.services.nix-daemon.environment.AWS_SHARED_CREDENTIALS_FILE = awsCreds;

  # ROOT bypasses the daemon (local store) — e.g. `sudo nixos-rebuild` — and
  # sudo strips the env var, so credential-less S3 lookups fell through to the
  # IMDS probe (~6s timeout PER PATH). Give root the standard credentials
  # path instead; recreated every boot (ephemeral /root).
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
