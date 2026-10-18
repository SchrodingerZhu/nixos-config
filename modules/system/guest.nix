# Guest account: an ordinary unprivileged login with its OWN home.
#
#   * Sees exactly the system-level software (environment.systemPackages,
#     programs.*, the niri session) -- NOT schrodingerzy's home-manager
#     packages or dotfiles, which live in that user's profile.
#   * Isolated home: /home/guest (mode 0700), and /home/schrodingerzy is 0700,
#     so neither user can read the other's files. /home is a persistent
#     dataset, so the guest's files survive reboots like everyone else's.
#   * No wheel (no sudo), no networkmanager, no novpn (traffic stays on the
#     VPN where the host runs one), no SSH keys (sshd is key-only -> no remote
#     login). Seat devices (GPU, audio) come from logind ACLs, not groups.
#
# Password: mutableUsers = false, so the hash comes from a persistent file
# (outside the repo). Until it exists the account is locked:
#   mkpasswd -m yescrypt | sudo tee /persist/secrets/guest.hash >/dev/null
#   sudo chmod 600 /persist/secrets/guest.hash
{ pkgs, ... }:
{
  users.users.guest = {
    isNormalUser = true;
    description = "Guest";
    homeMode = "700";
    shell = pkgs.fish;
    hashedPasswordFile = "/persist/secrets/guest.hash";
  };

  # Instructions for coding agents run by the guest. Copied only when absent,
  # so the guest may edit or delete it; remove it to get the current version back.
  systemd.tmpfiles.rules = [
    "C /home/guest/AGENTS.md 0644 guest users - ${./guest-AGENTS.md}"
  ];
}
