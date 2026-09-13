# Shared S3 compiler cache for both hosts.
# Cargo uses sccache globally with incremental compilation disabled.
# Use `env -u RUSTC_WRAPPER cargo build` when the cache is unavailable.
{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.sccache ];

  # Trust the cache server's private CA.
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
