# Disko layout for "manifold" — ASUS ROG Flow Z13 (GZ302EA, Strix Halo).
#   * Single NVMe (WD PC SN5000S, 1 TB): GPT -> [ ESP (1G, vfat) | ZFS (rest) ]
#   * Single pool "rpool" from ONE top-level vdev on the ZFS partition.
#     No mirror, no stripe -- it's a single-disk pool. (This laptop has one M.2
#     slot; no redundancy is available.)
#   * ZFS native encryption (aes-256-gcm), passphrase prompted at create/boot.
#   * compression=zstd, ashift=12, xattr=sa, acltype=posixacl, atime=off,
#     autotrim=on. dedup = blake3 on EVERY dataset (matches the workstation
#     spec; can be turned off later per-dataset with `zfs set dedup=off`).
#   * Ephemeral root: rpool/local/root gets an @blank snapshot at create time;
#     initrd rolls back to it every boot (see modules/system/impermanence.nix).
#   * Persistent datasets that survive the wipe: /nix, /home, /persist (+ the ESP).
{
  disko.devices = {
    disk = {
      nvme0 = {
        type = "disk";
        # WD PC SN5000S SDEQTSJ-1T00-1002, serial 25472A800077 -- stable by-id.
        device = "/dev/disk/by-id/nvme-WD_PC_SN5000S_SDEQTSJ-1T00-1002_25472A800077";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              name = "ESP-nvme0";
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
                extraArgs = [ "-n" "ESP-NVME0" ];
              };
            };
            zfs = {
              name = "zfs-nvme0";
              size = "100%";
              content = {
                type = "zfs";
                pool = "rpool";
              };
            };
          };
        };
      };
    };

    zpool = {
      rpool = {
        type = "zpool";
        # Single vdev -> the pool consists of just one disk. mode = "" keeps it
        # a plain top-level vdev (no mirror/raidz possible with one device).
        mode = "";

        options = {
          ashift = "12";
          autotrim = "on";
        };

        rootFsOptions = {
          compression = "zstd";
          acltype = "posixacl";
          xattr = "sa";
          atime = "off";
          mountpoint = "none";
          dedup = "blake3";
          "com.sun:auto-snapshot" = "false";
          encryption = "aes-256-gcm";
          keyformat = "passphrase";
          keylocation = "prompt";
        };

        datasets = {
          # Ephemeral root: wiped to @blank on every boot.
          "local/root" = {
            type = "zfs_fs";
            mountpoint = "/";
            postCreateHook = "zfs snapshot rpool/local/root@blank";
          };

          # Persistent: nix store.
          "local/nix" = {
            type = "zfs_fs";
            mountpoint = "/nix";
          };

          # Persistent: user data.
          "safe/home" = {
            type = "zfs_fs";
            mountpoint = "/home";
          };

          # Persistent: everything that must survive the root wipe
          # (/etc/nixos + git repo, machine-id, ssh host keys, NM profiles,
          #  KeePassXC db, var/lib state, secrets, ...).
          "safe/persist" = {
            type = "zfs_fs";
            mountpoint = "/persist";
          };
        };
      };
    };
  };
}
