# SSH client side + the single ssh-agent that KeePassXC feeds.
#
# KeePassXC does NOT provide an agent socket (it attaches to $SSH_AUTH_SOCK and
# adds keys to whatever agent is there). So we run exactly ONE plain ssh-agent,
# bound to the stable socket ~/.ssh/agent.socket, and disable every OTHER agent:
#   * home-manager services.ssh-agent (uses a different socket path) -> off here
#   * NixOS programs.ssh.startAgent                                  -> hosts/workstation/default.nix
#   * gpg-agent SSH support                                          -> never enabled
# KeePassXC then loads the DB's keys into this agent on unlock.
#
# fish caveat: fish does not source bash/zsh profile files. home.sessionVariables
# is exported via the PAM/systemd session, but we ALSO set SSH_AUTH_SOCK in fish's
# login init so every interactive fish session sees the right socket.
{ config, pkgs, ... }:
{
  # Disable home-manager's own ssh-agent (wrong socket path); we run our own.
  services.ssh-agent.enable = false;

  # One ssh-agent at the stable socket. KeePassXC (a client) populates it.
  systemd.user.services.keepassxc-ssh-agent = {
    Unit = {
      Description = "ssh-agent on a stable socket (~/.ssh/agent.socket) for KeePassXC";
      After = [ "default.target" ];
    };
    Install.WantedBy = [ "default.target" ];
    Service = {
      Type = "simple";
      ExecStartPre = [
        "${pkgs.coreutils}/bin/mkdir -p %h/.ssh"
        "-${pkgs.coreutils}/bin/rm -f %h/.ssh/agent.socket"
      ];
      ExecStart = "${pkgs.openssh}/bin/ssh-agent -D -a %h/.ssh/agent.socket";
      Restart = "on-failure";
    };
  };

  programs.fish.loginShellInit = ''
    set -gx SSH_AUTH_SOCK "$HOME/.ssh/agent.socket"
  '';
}
