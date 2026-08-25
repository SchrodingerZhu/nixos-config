# Unlock rpool at boot from a USB key stick, with clean fallback to the
# normal console passphrase prompt when the stick is absent.
#
# Mechanism: zfs-import-rpool asks for the passphrase via systemd-ask-password
# (3 tries, see nixpkgs zfs module). This initrd service runs IN PARALLEL with
# the import — deliberately no ordering against it — waits briefly for a vfat
# stick labeled ZFSKEY, reads /zfs-passphrase from it, and answers the pending
# ask-password request over its agent socket (systemd-reply-password), exactly
# as if the passphrase had been typed. No stick / no file => the console
# prompt behaves as before; a stick with a WRONG passphrase burns 1 of the 3
# tries and the remaining 2 stay interactive.
#
# The stick holds the passphrase in PLAIN TEXT: treat it like a written-down
# password. It defends against remote attackers and disk theft, not against
# someone who steals the machine and the stick together.
#
# Stick preparation (whole-device FAT, no partition table):
#   mkfs.vfat -I -n ZFSKEY /dev/sdX
#   mount /dev/sdX /mnt && printf '%s' "$PASSPHRASE" > /mnt/zfs-passphrase
{ config, pkgs, ... }:
{
  # USB mass storage is autoloaded by udev (usbhid/uas/sd_mod/xhci_pci are
  # already in hardware.nix); vfat + its codepages must be force-loaded since
  # nothing modprobes them for a manual mount(2) in initrd.
  boot.initrd.availableKernelModules = [ "usb_storage" ];
  boot.initrd.kernelModules = [
    "vfat"
    "nls_cp437"
    "nls_iso8859-1"
  ];

  # mount/umount are already in the initrd's /bin (util-linux-minimal, wired
  # up by the systemd stage-1 module); only the reply agent is missing.
  boot.initrd.systemd.extraBin = {
    systemd-reply-password = "${config.boot.initrd.systemd.package}/lib/systemd/systemd-reply-password";
  };

  boot.initrd.systemd.services.zfs-usb-unlock = {
    description = "Answer the rpool passphrase prompt from the ZFSKEY USB stick";
    wantedBy = [ "initrd.target" ];
    # Ordering only vs. udev (so the by-label symlink can appear) and shutdown;
    # NOT vs. zfs-import-rpool.service — that unit blocks on the prompt this
    # service answers, so any Before/After would deadlock or come too late.
    after = [ "systemd-udevd.service" ];
    before = [
      "initrd-switch-root.target"
      "shutdown.target"
    ];
    conflicts = [ "shutdown.target" ];
    unitConfig.DefaultDependencies = "no";
    serviceConfig.Type = "oneshot";
    script = ''
      dev=/dev/disk/by-label/ZFSKEY
      for _ in $(seq 100); do
        [ -e "$dev" ] && break
        sleep 0.1
      done
      if [ ! -e "$dev" ]; then
        echo "ZFSKEY stick not present; leaving the console prompt to it"
        exit 0
      fi

      mkdir -p /zfskey
      mount -t vfat -o ro "$dev" /zfskey || exit 0
      key=$(cat /zfskey/zfs-passphrase 2>/dev/null) || key=""
      umount /zfskey
      if [ -z "$key" ]; then
        echo "ZFSKEY stick has no /zfs-passphrase; leaving the console prompt"
        exit 0
      fi

      # Wait for the import unit's ask-password request (pool device discovery
      # can itself take up to 60s), then answer it over its agent socket.
      for _ in $(seq 900); do
        for ask in /run/systemd/ask-password/ask.*; do
          [ -e "$ask" ] || continue
          grep -q '^Message=Enter key for rpool' "$ask" || continue
          socket=$(sed -n 's/^Socket=//p' "$ask")
          [ -n "$socket" ] || continue
          printf '%s' "$key" | systemd-reply-password 1 "$socket" || true
          echo "answered the rpool key prompt from the USB stick"
          exit 0
        done
        sleep 0.1
      done
      echo "no rpool key prompt appeared within 90s; giving up"
    '';
  };
}
