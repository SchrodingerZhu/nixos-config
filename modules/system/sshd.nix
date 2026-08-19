# Inbound SSH (the REAL daemon). Shared by every host.
#
#   * sshd listens on :5678 ONLY, public-key auth ONLY (no passwords, no
#     keyboard-interactive, no root login).
#   * The well-known port :22 is handed to a Cowrie honeypot instead -- see
#     modules/system/cowrie.nix.
#
# Ephemeral-root note: /etc is wiped every boot, so the host keys are kept on
# the persistent pool (/persist/etc/ssh). sshd's pre-start generates them there
# on first boot and reuses them afterwards, giving clients a STABLE host
# identity across the rollback (no "REMOTE HOST IDENTIFICATION HAS CHANGED").
{ ... }:
{
  services.openssh = {
    enable = true;
    ports = [ 5678 ];
    openFirewall = true; # opens 5678/tcp in the nftables firewall

    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      AuthenticationMethods = "publickey"; # key-only, belt-and-braces
      PermitRootLogin = "no";
    };

    # Host keys on the persistent dataset so they survive the every-boot wipe.
    hostKeys = [
      {
        path = "/persist/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];
  };

  # Authorized public key(s) for inbound login. This is the ed25519 key already
  # present on the workstation (~/.ssh/id_ed25519.pub); append more lines here
  # for other client machines/keys.
  users.users.schrodingerzy.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII3MmPmNv0RjGULxJZCDhVYg0HIpJU0LVlSIzXsPyFVy"
  ];
}
