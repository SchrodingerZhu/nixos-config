# Cloudflare Tunnel (free plan) exposing the real sshd.
# WORKSTATION ONLY: the laptop is mobile and only ever acts as a client.
#
# The tunnel is "remotely managed": its ingress rule (public hostname ->
# ssh://localhost:5678) lives in the Cloudflare Zero Trust dashboard, so this
# host only needs the connector token -- no tunnel id or cert.pem in the repo.
#   echo -n '<token>' | sudo tee /persist/secrets/cloudflared-tunnel.token >/dev/null
#   sudo chmod 600 /persist/secrets/cloudflared-tunnel.token
# Until that file exists the unit is skipped (ConditionPathExists), not failed.
#
# Nothing is opened in the firewall: cloudflared only dials OUT to Cloudflare's
# edge. It runs in the `novpn` group (modules/system/vpn.nix) so that connection
# goes DIRECT instead of through ProtonVPN (QUIC/UDP over the tunnel is flaky,
# and the extra hop adds latency to every keystroke).
{ pkgs, ... }:
{
  systemd.services.cloudflared-tunnel = {
    description = "Cloudflare Tunnel connector (SSH)";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" "nftables.service" "dnsmasq-direct.service" ];
    unitConfig.ConditionPathExists = "/persist/secrets/cloudflared-tunnel.token";
    serviceConfig = {
      Type = "notify";
      DynamicUser = true;
      Group = "novpn";
      # Root-only secret handed to the dynamic user via the credentials dir.
      LoadCredential = "token:/persist/secrets/cloudflared-tunnel.token";
      ExecStart = "${pkgs.cloudflared}/bin/cloudflared tunnel --no-autoupdate run --token-file %d/token";
      Restart = "on-failure";
      RestartSec = 5;
      ProtectHome = true;
      ProtectSystem = "strict";
      PrivateTmp = true;
      NoNewPrivileges = true;
    };
  };
}
