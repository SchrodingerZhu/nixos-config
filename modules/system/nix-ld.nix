# nix-ld: run unpatched dynamically-linked binaries. Shared by every host.
#
# Needed for VS Code Remote-SSH: the client scp's a prebuilt vscode-server
# (its own node binary + native extension helpers) into ~/.vscode-server and
# execs it. Those ELFs hard-code /lib64/ld-linux-x86-64.so.2, which does not
# exist on NixOS, so they die with "No such file or directory". nix-ld
# installs a shim at that path that loads the real glibc ld.so and adds the
# libraries below to the search path.
#
# The module's default library set (glibc, libstdc++, zlib, openssl, curl,
# xz, ...) covers the server and the usual native extensions (cpptools,
# rust-analyzer's bundled bits, etc.). Extend `libraries` if an extension's
# binary complains about a missing .so.
#
# /home is a persistent ZFS dataset, so ~/.vscode-server survives the
# every-boot root wipe and the server is not re-downloaded each boot.
{ ... }:
{
  programs.nix-ld.enable = true;
}
