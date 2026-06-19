# CachyOS kernel via the overlay (overlay added in flake.nix) + matched ZFS.
#
# Plain "latest" line, Clang+ThinLTO, znver4 (EEVDF default scheduler) -- NOT
# any -bore/-rt/-hardened/-lts/etc. variant. Attr verified to exist & evaluate
# (kernel 7.1.0) via `nix eval` of the release branch overlay.
{ config, pkgs, ... }:
{
  boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-latest-lto-zen4;

  # ZFS from the CachyOS overlay, version-matched to this kernel (ZFS 2.4.3).
  # NOT the plain nixpkgs zfs/zfs_unstable. Fallback order if it won't build:
  #   config.boot.kernelPackages.zfs_2_3  ->  ..zfs_unstable  (stop & ask first).
  boot.zfs.package = config.boot.kernelPackages.zfs_cachyos;
}
