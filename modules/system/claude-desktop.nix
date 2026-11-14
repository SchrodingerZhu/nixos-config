# Host-side requirements for Claude Desktop's Cowork, which runs its tasks in
# a QEMU/KVM virtual machine. The app itself is a per-user GUI package
# (modules/home/packages.nix); its FHS env bundles virtiofsd and the OVMF
# firmware but takes qemu from the host PATH.
{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.qemu_kvm ]; # host-arch qemu-system only

  # /dev/vhost-vsock is only openable by the kvm group, even where the
  # logged-in user already gets /dev/kvm through uaccess.
  boot.kernelModules = [ "vhost_vsock" ];
  users.users.schrodingerzy.extraGroups = [ "kvm" ];
}
