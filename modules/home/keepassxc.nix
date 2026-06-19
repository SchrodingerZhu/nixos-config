# KeePassXC as BOTH the secret store and the SSH agent.
#
# It binds a stable agent socket at ~/.ssh/agent.socket (KeePassXC creates the
# socket named by $SSH_AUTH_SOCK when "use SSH_AUTH_SOCK env variable" is on),
# and $SSH_AUTH_SOCK points there globally (set here + reinforced for fish in
# ssh.nix). Competing agents are disabled in ssh.nix / host default.nix.
#
# The KeePassXC database itself lives under ~/ (in /home, persistent) and so
# survives the ephemeral-root wipe.
{ config, pkgs, lib, ... }:
{
  home.packages = [ pkgs.keepassxc ];

  # Stable agent socket consumed by ssh and every app that reads SSH_AUTH_SOCK.
  home.sessionVariables.SSH_AUTH_SOCK = "${config.home.homeDirectory}/.ssh/agent.socket";

  # Seed keepassxc.ini with the SSH-agent settings on first run only. We seed
  # (rather than symlink a read-only store file) so KeePassXC can still persist
  # its own runtime state into the same INI without being reset.
  home.activation.seedKeepassxcIni = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "${config.home.homeDirectory}/.ssh"
    run chmod 700 "${config.home.homeDirectory}/.ssh"
    cfg="${config.home.homeDirectory}/.config/keepassxc/keepassxc.ini"
    if [ ! -e "$cfg" ]; then
      run mkdir -p "$(dirname "$cfg")"
      run cat > "$cfg" <<'EOF'
[SSHAgent]
Enabled=true
UseSSHAgentEnvVariable=true

[Security]
IconDownloadFallback=false

[GUI]
MinimizeToTray=true
ShowTrayIcon=true
MinimizeOnClose=true
EOF
    fi
  '';
}
