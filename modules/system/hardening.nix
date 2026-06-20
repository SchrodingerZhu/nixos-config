# System hardening & resource management:
#   * native firewall (nftables backend, default-deny inbound)
#   * Ananicy-cpp (auto-nice daemon) with CachyOS rules
#   * systemd-oomd (userspace OOM) + zram (so oomd has swap pressure to act on)
#   * AppArmor LSM
{ pkgs, ... }:
{
  # --- Firewall: NixOS native, nftables backend, default-deny inbound ---
  networking.nftables.enable = true;
  networking.firewall.enable = true;
  # No ports opened here; services that need a port use their own openFirewall.

  # --- Ananicy-cpp (NOT the old shell ananicy) with CachyOS rule set ---
  services.ananicy = {
    enable = true;
    package = pkgs.ananicy-cpp;
    rulesProvider = pkgs.ananicy-rules-cachyos;
  };

  # --- systemd-oomd: kill runaway processes before a hard kernel OOM ---
  systemd.oomd = {
    enable = true;
    enableRootSlice = true;
    enableSystemSlice = true;
    enableUserSlices = true;
  };
  # No swap-on-disk on the stripe; zram gives oomd memory-pressure headroom.
  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  # --- AppArmor LSM (verify it's present in the CachyOS kernel post-install) ---
  security.apparmor = {
    enable = true;
    enableCache = true;
  };
  environment.systemPackages = [ pkgs.apparmor-utils ]; # aa-status

  # --- U2F (pam_u2f): enable the module + require it for login and sudo ---
  # control defaults to "sufficient", so a registered key OR the password works
  # (no lockout). Keys are read from ~/.config/Yubico/u2f_keys.
  security.pam.u2f.enable = true;
  security.pam.services = {
    login.u2fAuth = true;
    sudo.u2fAuth = true;
  };

  # --- pkexec: create the setuid-root wrapper (/run/wrappers/bin/pkexec) ---
  # polkit ships pkexec, but NixOS leaves the setuid wrapper OPT-IN (default
  # off), so without this pkexec fails with "must be setuid root". Tradeoff:
  # pkexec has a CVE history (e.g. PwnKit, CVE-2021-4034); the DMS polkit agent
  # already covers app-initiated prompts, so this is only needed to run commands
  # as root yourself via pkexec.
  security.polkit.enablePkexecWrapper = true;
}
