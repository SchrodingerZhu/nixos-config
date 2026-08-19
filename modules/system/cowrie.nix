# Cowrie -- interactive SSH/Telnet honeypot on the well-known port. Shared by
# every host. Replaces the earlier endlessh tarpit: instead of merely stalling
# scanners, Cowrie presents a full fake shell and logs the entire session
# (commands run, credentials tried, payloads downloaded).
#
# Cowrie is NOT packaged in nixpkgs, so it runs from the official upstream OCI
# image under podman (virtualisation.oci-containers). The image is pinned by
# digest for reproducibility.
#
#   * Host :22 -> the container's SSH listener on :2222. The REAL sshd is on
#     :5678 (modules/system/sshd.nix), so nothing but the honeypot ever answers
#     on :22.
#   * The image runs as its own unprivileged uid 999. Session logs and captured
#     payloads land in the container's var/, bind-mounted to /persist/cowrie/var
#     so they survive the every-boot root wipe. The podman image store
#     (/var/lib/containers) is persisted in modules/system/impermanence.nix, so
#     the image is pulled once, not on every reboot.
{ ... }:
{
  virtualisation.oci-containers = {
    backend = "podman";
    containers.cowrie = {
      # cowrie/cowrie 3.0.12 -- multi-arch index digest. Bump tag + digest
      # together (get the digest with:
      #   podman manifest inspect docker.io/cowrie/cowrie:<tag>).
      image = "docker.io/cowrie/cowrie@sha256:3e4ce75576e4dffc3397ae3ad8dbb00afa00fe826b1531fea50d4fd9728326e1";
      ports = [ "22:2222" ]; # honeypot SSH on the well-known port
      volumes = [
        "/persist/cowrie/var:/cowrie/cowrie-git/var" # session logs, downloads, tty recordings
      ];
      # The image's baked etc/ is left in place, so Cowrie runs on its shipped
      # defaults. To customise, add "/persist/cowrie/etc:/cowrie/cowrie-git/etc"
      # here and drop a cowrie.cfg (owned by uid 999) into that dir.
    };
  };

  # Cowrie's var/ must be writable by the image's uid/gid 999; create it on the
  # persistent pool before the container unit starts.
  systemd.tmpfiles.rules = [
    "d /persist/cowrie     0755 root root - -"
    "d /persist/cowrie/var 0750 999  999  - -"
  ];

  # Let scanners actually reach the honeypot.
  networking.firewall.allowedTCPPorts = [ 22 ];
}
