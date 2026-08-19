# General userland packages (not tied to a specific app module).
#
# Persistence note: these are declared in the flake, so they rebuild into /nix
# (a persistent dataset) on every switch. Any runtime data they create lives
# under $HOME (the safe/home dataset) and survives the ephemeral-root wipe with
# no extra environment.persistence entries.
#
# distrobox is just the CLI wrapper -- its container backend (rootless podman)
# and the sub-uid/gid ranges are configured at the system level
# (see the host's default.nix). steam is likewise enabled there via
# programs.steam, NOT here, so it gets the FHS env + controller udev rules.
{ pkgs, lib, osConfig, ... }:
let
  # The workstation runs everything through a ProtonVPN tunnel (modules/system/
  # vpn.nix), which creates a `novpn` group that is policy-routed to the
  # physical link. UDP/voice apps break through the tunnel, so wrap them to
  # launch in that group and go DIRECT. The laptop does NOT import vpn.nix
  # (no novpn group) -> use the plain packages there.
  hasNovpn = osConfig.users.groups ? novpn;

  # Wrap a package so its binary always runs OUTSIDE the VPN: it launches in the
  # `novpn` group via the setuid /run/wrappers/bin/sg. Launch the app normally
  # -- the .desktop entries use bare exec names, so they resolve to these
  # wrappers on PATH. Caveat: deep-link URL args (Exec %u/%U) aren't forwarded
  # through sg; use the `direct <cmd>` helper for those one-offs.
  directWrap =
    pkg: exe:
    let
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

  # Wrap only where the VPN (and thus the novpn group) exists; plain otherwise.
  maybeDirect = pkg: exe: if hasNovpn then directWrap pkg exe else pkg;
in
{
  home.packages = with pkgs; [
    python3
    distrobox
    claude-code
    codex
    vscode # Insiders isn't packaged in nixpkgs; using stable.
    gh # GitHub CLI
    obs-studio # screen capture via the gnome ScreenCast portal (see xdg.portal)
    (maybeDirect taterclient-ddnet "TaterClient-DDNet") # DDNet -- DIRECT under VPN (UDP breaks tunnelled)
    telegram-desktop
    sone # native Linux desktop client for TIDAL
    (maybeDirect vesktop "vesktop") # Discord -- DIRECT under VPN (voice breaks tunnelled)
    teams-for-linux # Microsoft Teams (official Linux client is discontinued)

    # System monitors
    fastfetch
    btop
    htop
    nvtopPackages.amd # AMD Radeon 8060S (RDNA 3.5) iGPU

    # Dev tools (direnv itself is configured in direnv.nix)
    texliveFull # full TeX Live (all packages) -- several GB
    ripgrep
  ];
}
