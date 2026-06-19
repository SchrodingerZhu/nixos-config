# KeePassXC as the secret store + SSH key manager.
#
# IMPORTANT: KeePassXC (2.7.x) is an SSH-agent *client*, not a standalone agent.
# It does NOT create a socket server — it attaches to the agent at $SSH_AUTH_SOCK
# (or SSHAgent/AuthSockOverride) and ADDS the database's SSH keys to it when the
# database is unlocked. So the actual agent is a single plain ssh-agent bound to
# ~/.ssh/agent.socket (see ssh.nix); KeePassXC populates it.
#
# The KeePassXC database lives under ~/ (in /home, persistent), so it survives
# the ephemeral-root wipe.
{ config, pkgs, lib, ... }:
{
  home.packages = [ pkgs.keepassxc ];

  # Stable agent socket consumed by ssh and every app that reads SSH_AUTH_SOCK.
  home.sessionVariables.SSH_AUTH_SOCK = "${config.home.homeDirectory}/.ssh/agent.socket";

  # Seed keepassxc.ini on first run only (mutable afterwards, so KeePassXC can
  # persist its own runtime state into the same file). Keys verified against
  # KeePassXC 2.7.12's src/core/Config.cpp:
  #   SSHAgent/Enabled, SSHAgent/AuthSockOverride, Security/IconDownloadFallback,
  #   GUI/MinimizeToTray, GUI/MinimizeOnClose, GUI/ShowTrayIcon.
  # (There is NO "UseSSHAgentEnvVariable" key — KeePassXC just uses the override
  # path or $SSH_AUTH_SOCK directly.)
  home.activation.seedKeepassxcIni = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "${config.home.homeDirectory}/.ssh"
    run chmod 700 "${config.home.homeDirectory}/.ssh"
    cfg="${config.home.homeDirectory}/.config/keepassxc/keepassxc.ini"
    if [ ! -e "$cfg" ]; then
      run mkdir -p "$(dirname "$cfg")"
      run cat > "$cfg" <<'EOF'
[SSHAgent]
Enabled=true
AuthSockOverride=${config.home.homeDirectory}/.ssh/agent.socket

[Security]
IconDownloadFallback=false

[GUI]
MinimizeToTray=true
MinimizeOnClose=true
ShowTrayIcon=true
EOF
    fi
  '';
}
