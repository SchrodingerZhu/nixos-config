# rustfs — S3-compatible object store backing the fleet-wide sccache cache
# (workstation only; clients are configured in modules/system/sccache.nix).
#
# Storage: dedicated dataset rpool/safe/rustfs mounted at /var/lib/rustfs with
# quota=200G (sccache never evicts server-side; the quota is the size cap —
# wiping /var/lib/rustfs is always safe, it's only cache). Declared in
# hosts/workstation/disko.nix for reinstall parity; on the live system it was
# created with:
#   zfs create -o quota=200G -o mountpoint=/var/lib/rustfs rpool/safe/rustfs
#
# TLS: serves HTTPS using /persist/secrets/rustfs-tls/{rustfs_cert.pem,
# rustfs_key.pem} (exact filenames rustfs expects) — a leaf signed by the
# private CA committed at ./rustfs-ca.crt (clients trust it via security.pki).
# SANs: IP:192.168.0.92, DNS:workstation, DNS:schrodingerzy. CA key for
# future leaf rotation: /persist/secrets/ca.key (root, workstation only).
#
# Secrets (NOT in git): /persist/secrets/rustfs.env holds
# RUSTFS_ACCESS_KEY/RUSTFS_SECRET_KEY (also the clients' S3 credentials).
{ ... }:
{
  services.rustfs = {
    enable = true;
    settings = {
      RUSTFS_ADDRESS = "0.0.0.0:9000";
      RUSTFS_CONSOLE_ENABLE = "false";
      RUSTFS_TLS_PATH = "/persist/secrets/rustfs-tls";
      # RUSTFS_VOLUMES stays at its default /var/lib/rustfs (the dataset).
    };
    environmentFile = "/persist/secrets/rustfs.env";
  };

  networking.firewall.allowedTCPPorts = [ 9000 ];

  # Never write into an unmounted /var/lib/rustfs (ephemeral root underneath).
  systemd.services.rustfs = {
    after = [ "zfs-mount.service" ];
    requires = [ "zfs-mount.service" ];
  };

  # TLS material stays root-OWNED with group access for the service user:
  # tmpfiles refuses to chown files under a non-root-owned directory ("unsafe
  # path transition" guard), so granting via the rustfs GROUP is the way that
  # actually applies. Runs every boot/activation (the rustfs user/group only
  # exist post-switch).
  systemd.tmpfiles.rules = [
    "z /persist/secrets/rustfs-tls 0750 root rustfs -"
    "z /persist/secrets/rustfs-tls/rustfs_cert.pem 0640 root rustfs -"
    "z /persist/secrets/rustfs-tls/rustfs_key.pem 0640 root rustfs -"
  ];
}
