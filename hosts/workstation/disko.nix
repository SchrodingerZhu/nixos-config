# Disko layout for schrodingerzy:
#   * Two NVMe SSDs, each: GPT -> [ ESP (1G, vfat) | ZFS (rest) ]
#   * Single pool "rpool" built as a NON-REDUNDANT STRIPE (RAID0):
#     both ZFS partitions are plain top-level vdevs (mode = ""), so capacity is
#     the sum of both disks and there is NO redundancy. Losing either NVMe loses
#     the whole pool. (Confirmed with the operator.)
#   * ZFS native encryption (aes-256-gcm), passphrase prompted at create/boot.
#   * compression=zstd, ashift=12, xattr=sa, acltype=posixacl, atime=off,
#     autotrim=on. dedup = blake3 (ZFS fast-dedup) on EVERY dataset including
#     the pool root and nix store (operator override of the original spec).
#   * Ephemeral root: rpool/local/root gets an @blank snapshot at create time;
#     initrd rolls back to it every boot (see modules/system/impermanence.nix).
#   * Persistent datasets that survive the wipe: /nix, /home, /persist (+ ESPs).
#
# Every partition has a GLOBALLY UNIQUE label (disko issue #551 hardening):
# ESP-nvme0 / ESP-nvme1 and zfs-nvme0 / zfs-nvme1 — never generic "ESP".
{
  disko.devices = {
    disk = {
      nvme0 = {
        type = "disk";
        # nvme0n1, serial N2245RM800D7 — stable by-id (EUI) path.
        device = "/dev/disk/by-id/nvme-eui.00000006240507979c2d4905500010eb";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              name = "ESP-nvme0"; # unique GPT partlabel
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
                # Unique FAT volume label so /boot and /boot-fallback never alias.
                extraArgs = [ "-n" "ESP-NVME0" ];
              };
            };
            zfs = {
              name = "zfs-nvme0"; # unique GPT partlabel
              size = "100%";
              content = {
                type = "zfs";
                pool = "rpool";
              };
            };
          };
        };
      };

      nvme1 = {
        type = "disk";
        # nvme1n1, serial N2245RM800F0 — stable by-id (EUI) path.
        device = "/dev/disk/by-id/nvme-eui.00000006240507979c2d4905500010e2";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              name = "ESP-nvme1"; # unique GPT partlabel
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot-fallback";
                mountOptions = [ "umask=0077" ];
                extraArgs = [ "-n" "ESP-NVME1" ];
              };
            };
            zfs = {
              name = "zfs-nvme1"; # unique GPT partlabel
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
        # mode = "" => plain stripe across the two vdevs (NO mirror/raidz).
        mode = "";

        # Pool-level (-o) properties.
        options = {
          ashift = "12";
          autotrim = "on";
        };

        # Root-dataset (-O) properties, inherited by all child datasets
        # (including encryption -> the whole pool is encrypted).
        rootFsOptions = {
          compression = "zstd";
          acltype = "posixacl";
          xattr = "sa";
          atime = "off";
          mountpoint = "none";
          # Fast-dedup with blake3, inherited by ALL child datasets (incl. nix).
          dedup = "blake3";
          "com.sun:auto-snapshot" = "false";
          # Native encryption, passphrase prompted (create time + every boot).
          encryption = "aes-256-gcm";
          keyformat = "passphrase";
          keylocation = "prompt";
        };

        datasets = {
          # --- Ephemeral root: wiped to @blank on every boot ---
          "local/root" = {
            type = "zfs_fs";
            mountpoint = "/";
            # Blank snapshot taken right after creation; initrd rolls back to it.
            postCreateHook = "zfs snapshot rpool/local/root@blank";
          };

          # --- Persistent: nix store. Inherits dedup=blake3 + compression=zstd. ---
          "local/nix" = {
            type = "zfs_fs";
            mountpoint = "/nix";
          };

          # --- Persistent: user data ---
          "safe/home" = {
            type = "zfs_fs";
            mountpoint = "/home";
          };

          # --- Persistent: everything that must survive the root wipe
          #     (/etc/nixos + git repo, machine-id, ssh host keys, NM profiles,
          #      KeePassXC db, var/lib state, ...) ---
          "safe/persist" = {
            type = "zfs_fs";
            mountpoint = "/persist";
          };
        };
      };
    };
  };
}
