# CachyOS kernel via the overlay (overlay added in flake.nix) + matched ZFS.
#
# Plain "latest" line, Clang+ThinLTO, x86_64-v4 (generic AVX-512 baseline that
# runs on Strix Halo / Zen 5 -- the overlay has no znver5-tuned variant yet,
# and the znver4-tuned build would be a strict subset of what Zen 5 supports).
# Attr verified to exist in the pinned release branch (kernel 7.1.0).
{ config, pkgs, ... }:
{
  boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-latest-lto-x86_64-v4;

  # ZFS from the CachyOS overlay, version-matched to this kernel (ZFS 2.4.3).
  # NOT the plain nixpkgs zfs/zfs_unstable. Fallback order if it won't build:
  #   config.boot.kernelPackages.zfs_2_3  ->  ..zfs_unstable  (stop & ask first).
  boot.zfs.package = config.boot.kernelPackages.zfs_cachyos;
}
