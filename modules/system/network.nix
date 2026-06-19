# Networking: NetworkManager. The live WiFi profile (TMOBILE-7D10) is copied
# into /persist/etc/NetworkManager/system-connections during install -- it
# contains the PSK in plaintext, so it lives ONLY on the encrypted pool and is
# NEVER committed to this git repo. /etc/NetworkManager/system-connections is a
# persisted directory (see modules/system/impermanence.nix).
{ ... }:
{
  networking.networkmanager.enable = true;
}
