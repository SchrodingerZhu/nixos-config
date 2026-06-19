# SSH client side + making sure the KeePassXC agent socket reaches every shell.
#
# All competing agents are disabled:
#   * home-manager services.ssh-agent  -> here
#   * NixOS programs.ssh.startAgent     -> hosts/workstation/default.nix
#   * gpg-agent SSH support             -> not enabled at all
#
# fish caveat: fish does not source bash/zsh profile files. home.sessionVariables
# is exported via the PAM/systemd session (so graphical apps and login fish see
# it), but we ALSO set it in fish's login init so EVERY interactive fish session
# has the right SSH_AUTH_SOCK regardless of launch path.
{ config, ... }:
{
  services.ssh-agent.enable = false;

  programs.fish.loginShellInit = ''
    set -gx SSH_AUTH_SOCK "$HOME/.ssh/agent.socket"
  '';
}
