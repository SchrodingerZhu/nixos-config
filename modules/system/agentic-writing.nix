# Agentic writing cluster: central server on the workstation, CPU workers on
# every host, GPU worker on the laptop (ROCm). The third node (aarch64, not
# NixOS) runs its workers as user services. Nodes talk over a dedicated
# WireGuard network, separate from the Proton tunnels: its routes live in
# `main`, so rule 150 in vpn.nix keeps them off the VPN.
#
# Secrets (outside this repo, 0400), in /persist/secrets/agentic-writing/:
#   wg.key         WireGuard private key of this host
#   cluster.token  shared token for workers and gateways
#   ASD-STE100_ISSUE9.pdf  (workstation) the licensed STE specification
#   hf.token       (laptop) Hugging Face token for model downloads
{ inputs, config, lib, ... }:
let
  isManifold = config.networking.hostName == "manifold";
  secrets = "/persist/secrets/agentic-writing";
  serverAddress = "10.77.0.1:7400";

  peers = {
    workstation = {
      publicKey = "B2e32VsPJbxFycEKpai9WAxImJYtVI6qrZGc+cfCUmc=";
      endpoint = "192.168.0.92:51871";
      allowedIPs = [ "10.77.0.1/32" ];
    };
    manifold = {
      publicKey = "3+/Px36Y4tmyB0IDp9JkTbILQ/PXFADosJgRNM2M0gk=";
      endpoint = "192.168.0.60:51871";
      allowedIPs = [ "10.77.0.2/32" ];
    };
    spark = {
      publicKey = "NbU7Nicu8KnDcovLZQj22LQqgP9NgAq0vtBKrMQPdSc=";
      endpoint = "192.168.0.58:51871";
      allowedIPs = [ "10.77.0.3/32" ];
    };
  };
  self = if isManifold then "manifold" else "workstation";
in
{
  imports = [ inputs.agentic-writing-mcp.nixosModules.default ];

  services.agentic-writing = {
    clusterTokenFile = "${secrets}/cluster.token";
    adminUsers = [ "schrodingerzy" ];

    wireguard = {
      enable = true;
      address = if isManifold then "10.77.0.2/24" else "10.77.0.1/24";
      privateKeyFile = "${secrets}/wg.key";
      peers = lib.mapAttrsToList (name: p: p // { inherit name; })
        (lib.filterAttrs (name: _: name != self) peers);
    };

    server = lib.mkIf (!isManifold) {
      enable = true;
      listen = serverAddress;
      steSpecFile = "${secrets}/ASD-STE100_ISSUE9.pdf";
    };

    gateway = lib.mkIf isManifold {
      enable = true;
      inherit serverAddress;
    };

    worker.cpu = {
      enable = true;
      inherit serverAddress;
      nodeName = self;
    };

    worker.gpu = lib.mkIf isManifold {
      enable = true;
      backend = "rocm";
      inherit serverAddress;
      nodeName = "manifold";
      hfTokenFile = "${secrets}/hf.token";
      # The iGPU can map ~65 GiB (TTM limit); leave headroom for the desktop.
      memoryBudget = "56GiB";
    };

    mcp.users = [ "schrodingerzy" "guest" ];
  };

  # Job store and pause state; models, artifacts and the result cache (the
  # cache carries a CACHEDIR.TAG, so restic skips it).
  environment.persistence."/persist".directories =
    map
      (directory: {
        inherit directory;
        user = "agentic-writing";
        group = "agentic-writing";
        mode = "0750";
      })
      [
        "/var/lib/agentic-writing"
        "/var/cache/agentic-writing"
      ];
}
