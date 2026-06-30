# General userland packages (not tied to a specific app module).
#
# Persistence note: these are declared in the flake, so they rebuild into /nix
# (a persistent dataset) on every switch. Any runtime data they create lives
# under $HOME (the safe/home dataset) and survives the ephemeral-root wipe with
# no extra environment.persistence entries.
#
# distrobox is just the CLI wrapper — its container backend (rootless podman)
# and the sub-uid/gid ranges are configured at the system level
# (see hosts/workstation/default.nix). steam is likewise enabled there via
# programs.steam, NOT here, so it gets the FHS env + controller udev rules.
{ pkgs, ... }:
let
  # Wrap a package so its binary always runs OUTSIDE the VPN: it launches in the
  # `novpn` group, which the vpn module (modules/system/vpn.nix) marks and
  # policy-routes to the physical link. Launch the app normally -- the .desktop
  # entries use bare exec names, so they resolve to these wrappers on PATH, and
  # there is no separate "-direct" command. Uses the setuid /run/wrappers/bin/sg
  # to switch group (you must be a member of `novpn`, set up by the vpn module).
  # Caveat: deep-link URL args (Exec %u/%U) aren't forwarded through sg; use the
  # `direct <cmd>` helper for those one-offs.
  directWrap =
    pkg: exe:
    let
      # the setuid sg lives at a runtime path, so write the wrapper by hand
      # (makeWrapper refuses targets that don't exist at build time).
      runner = pkgs.writeShellScript "${exe}-novpn" ''
        exec /run/wrappers/bin/sg novpn -c "${pkg}/bin/${exe}"
      '';
    in
    pkgs.symlinkJoin {
      name = "${exe}-novpn";
      paths = [ pkg ];
      postBuild = ''
        rm $out/bin/${exe}
        ln -s ${runner} $out/bin/${exe}
      '';
    };
in
{
  home.packages = with pkgs; [
    python3
    distrobox
    claude-code
    vscode # Insiders isn't packaged in nixpkgs; using stable.
    gh # GitHub CLI
    obs-studio # screen capture via the gnome ScreenCast portal (see xdg.portal)
    (directWrap taterclient-ddnet "TaterClient-DDNet") # DDNet — forced DIRECT (UDP breaks via VPN)
    telegram-desktop
    sone # native Linux desktop client for TIDAL
    (directWrap vesktop "vesktop") # Discord — forced DIRECT (voice breaks via VPN)

    # System monitors
    fastfetch
    btop
    htop
    nvtopPackages.amd # AMD RDNA2 iGPU only (no NVIDIA); use .full for all vendors

    # Dev tools (direnv itself is configured in direnv.nix)
    jetbrains.rust-rover
  ];
}
