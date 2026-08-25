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
# The stick carries the passphrase TPM-SEALED (systemd-creds, --with-key=tpm2):
# /zfs-key.cred only decrypts on THIS machine's TPM2, so a stolen or lost
# stick reveals nothing by itself. A plain-text /zfs-passphrase file is still
# honored as a secondary path (useful for a break-glass stick kept elsewhere).
# TPM caveat: a firmware update / secure-boot change can rotate the sealing
# PCRs — decryption then fails, boot falls back to the prompt, and the stick
# needs re-encrypting (same commands as below).
#
# Stick preparation (whole-device FAT, no partition table):
#   systemd-creds encrypt --with-key=tpm2 --name=zfs-key /tmp/key /tmp/zfs-key.cred
#   mkfs.vfat -I -n ZFSKEY /dev/sdX
#   mount /dev/sdX /mnt && cp /tmp/zfs-key.cred /mnt/zfs-key.cred
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
    "nls_ascii" # kernel's FAT_DEFAULT_IOCHARSET — mount fails without it
  ];

  # TPM2 in stage 1: tpm-crb/tpm-tis kernel modules + tpm2-tss libraries
  # (systemd dlopens them by absolute store path, so systemd-creds works).
  boot.initrd.systemd.tpm2.enable = true;

  # mount/umount are already in the initrd's /bin (util-linux-minimal, wired
  # up by the systemd stage-1 module); the reply agent and creds tool are not.
  boot.initrd.systemd.extraBin = {
    systemd-reply-password = "${config.boot.initrd.systemd.package}/lib/systemd/systemd-reply-password";
    systemd-creds = "${config.boot.initrd.systemd.package}/bin/systemd-creds";
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
      key=""
      if [ -e /zfskey/zfs-key.cred ]; then
        # Give the fTPM a moment to show up (tpm-crb loads via udev).
        for _ in $(seq 50); do
          [ -e /dev/tpmrm0 ] && break
          sleep 0.1
        done
        key=$(systemd-creds decrypt --name=zfs-key --tpm2-device=auto /zfskey/zfs-key.cred - 2>/dev/null) \
          || { key=""; echo "TPM decryption of zfs-key.cred failed"; }
      fi
      if [ -z "$key" ]; then
        key=$(cat /zfskey/zfs-passphrase 2>/dev/null) || key=""
      fi
      umount /zfskey
      if [ -z "$key" ]; then
        echo "ZFSKEY stick yielded no usable key; leaving the console prompt"
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
