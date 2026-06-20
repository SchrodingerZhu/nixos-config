# direnv + nix-direnv — the standard Nix best-practice setup.
#
# nix-direnv replaces direnv's slow built-in `use nix`/`use flake` with a fast,
# cached implementation and, crucially, pins the flake/devshell closure with a
# GC root under each project's .direnv/ so `nix.gc` (weekly, --delete-older-than
# 30d) won't collect an in-use dev environment.
#
# Per-project usage: drop a `.envrc` containing `use flake` (or `use nix`) and
# run `direnv allow`. Fish integration is wired automatically because
# programs.fish.enable is set (see shell.nix).
{ ... }:
{
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    # silent = true;  # uncomment to suppress direnv's load/unload chatter
  };
}
