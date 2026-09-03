# sccache client side (BOTH hosts): shared S3 compile cache on the
# workstation's rustfs (modules/system/rustfs.nix).
#
# RUSTC_WRAPPER/CARGO_INCREMENTAL are set GLOBALLY below (operator choice):
# every cargo build on these machines caches with no per-project setup.
# Trade-offs: incremental compilation is off everywhere (cold rebuilds are
# what the cache accelerates), and builds need rustfs reachable — to build
# fully locally in a pinch: `env -u RUSTC_WRAPPER cargo build`.
# Inspect with `sccache --show-stats`.
#
# The S3 settings ride global env vars (below). S3 credentials:
# AWS_SHARED_CREDENTIALS_FILE points at /persist/secrets/sccache/aws-credentials
# — override per-shell if real AWS credentials are ever needed.
#
# Caveat: with SCCACHE_BUCKET set globally, an sccache daemon started while
# rustfs is unreachable fails to init its backend — `unset SCCACHE_BUCKET`
# (or stop using the wrapper) to build with rustfs down.
{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.sccache ];

  # Trust the private CA that signs the rustfs TLS leaf (public cert, in git).
  security.pki.certificateFiles = [ ./rustfs-ca.crt ];

  environment.variables = {
    SCCACHE_BUCKET = "sccache";
    SCCACHE_ENDPOINT = "https://192.168.0.92:9000";
    SCCACHE_REGION = "auto";
    AWS_SHARED_CREDENTIALS_FILE = "/persist/secrets/sccache/aws-credentials";
    RUSTC_WRAPPER = "sccache";
    CARGO_INCREMENTAL = "0";
  };
}
