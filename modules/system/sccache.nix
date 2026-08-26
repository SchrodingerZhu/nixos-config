# sccache client side (BOTH hosts): shared S3 compile cache on the
# workstation's rustfs (modules/system/rustfs.nix) + distributed compilation
# via its sccache-dist scheduler (modules/system/sccache-dist.nix).
#
# PROJECT USAGE — a flake devShell opts in with exactly:
#   RUSTC_WRAPPER = "sccache";
#   CARGO_INCREMENTAL = "0";   # sccache can't cache/distribute incremental
#                              # builds; without this, dev builds stay local
# Inspect with `sccache --show-stats` and `sccache --dist-status`.
#
# The S3 settings ride global env vars (below); the dist scheduler URL + auth
# token live in ~/.config/sccache/config -> /persist/secrets/sccache/config.toml
# (user-readable, NOT in git). S3 credentials: AWS_SHARED_CREDENTIALS_FILE
# points at /persist/secrets/sccache/aws-credentials — override per-shell if
# real AWS credentials are ever needed.
#
# Caveat: with SCCACHE_BUCKET set globally, an sccache daemon started while
# rustfs is unreachable fails to init its backend — `unset SCCACHE_BUCKET`
# (or stop using the wrapper) to build with rustfs down.
{ pkgs, ... }:
let
  sccacheDist = pkgs.sccache.override { distributed = true; }; # dist-client build
in
{
  environment.systemPackages = [ sccacheDist ];

  # Trust the private CA that signs the rustfs TLS leaf (public cert, in git).
  security.pki.certificateFiles = [ ./rustfs-ca.crt ];

  environment.variables = {
    SCCACHE_BUCKET = "sccache";
    SCCACHE_ENDPOINT = "https://192.168.0.92:9000";
    SCCACHE_REGION = "auto";
    AWS_SHARED_CREDENTIALS_FILE = "/persist/secrets/sccache/aws-credentials";
  };

  # ~/.config/sccache/config -> the secret-bearing dist config on /persist.
  home-manager.users.schrodingerzy =
    { config, ... }:
    {
      xdg.configFile."sccache/config".source =
        config.lib.file.mkOutOfStoreSymlink "/persist/secrets/sccache/config.toml";
    };
}
