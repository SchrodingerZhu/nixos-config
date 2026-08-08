# CachyOS kernel via the overlay (overlay added in flake.nix) + matched ZFS.
#
# Plain "latest" line, Clang+ThinLTO, zen4-tuned (closest march to Strix Halo /
# Zen 5 -- the overlay has no znver5-tuned variant yet; znver4 scheduling and
# ISA are a compatible subset of Zen 5).
# Attr verified to exist in the pinned release branch (kernel 7.1.0).
{ config, pkgs, ... }:
{
  boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-latest-lto-zen4;

  # ZFS from the CachyOS overlay, version-matched to this kernel (ZFS 2.4.3).
  # NOT the plain nixpkgs zfs/zfs_unstable. Fallback order if it won't build:
  #   config.boot.kernelPackages.zfs_2_3  ->  ..zfs_unstable  (stop & ask first).
  boot.zfs.package = config.boot.kernelPackages.zfs_cachyos;
}
