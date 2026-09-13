# Workstation S3 cache. The client endpoint and shared credentials are configured
# in sccache.nix and nix.nix. All mutable state lives on a dedicated ZFS dataset.
{ pkgs, lib, ... }:
let
  dataDir = "/var/lib/seaweedfs";
  # RustFS continues serving :9000 until the cache copy and client checks pass.
  s3Port = 9002;
  weed = "${pkgs.seaweedfs}/bin/weed";
  service =
    {
      description,
      args,
      subdir,
      dependencies ? [ ],
      extraServiceConfig ? { },
      preStart ? "",
    }:
    {
      inherit description;
      wantedBy = [ "multi-user.target" ];
      after = [ "zfs-mount.service" ] ++ dependencies;
      requires = [ "zfs-mount.service" ] ++ dependencies;
      unitConfig = {
        RequiresMountsFor = [
          dataDir
          "/persist"
        ];
        ConditionPathIsMountPoint = dataDir;
        PartOf = dependencies;
        StartLimitIntervalSec = 0;
      };
      preStart = ''
        ${pkgs.coreutils}/bin/mkdir -p ${dataDir}/${subdir}
        ${preStart}
      '';
      serviceConfig = {
        User = "seaweedfs";
        Group = "seaweedfs";
        StateDirectory = "seaweedfs";
        StateDirectoryMode = "0700";
        WorkingDirectory = dataDir;
        ExecStart = "${weed} ${lib.escapeShellArgs args}";
        Restart = "on-failure";
        RestartSec = 3;
        TimeoutStopSec = 60;
        UMask = "0077";
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
      }
      // extraServiceConfig;
    };
in
{
  users.users.seaweedfs = {
    isSystemUser = true;
    group = "seaweedfs";
  };
  users.groups.seaweedfs = { };

  environment.systemPackages = [ pkgs.seaweedfs ];
  networking.firewall.allowedTCPPorts = [ s3Port ];

  environment.etc."seaweedfs/filer.toml".text = ''
    [leveldb2]
    enabled = true
    dir = "${dataDir}/filer"
  '';

  systemd.services.seaweedfs-master = service {
    description = "SeaweedFS cache master";
    subdir = "master";
    args = [
      "master"
      "-ip=127.0.0.1"
      "-ip.bind=127.0.0.1"
      "-port=9333"
      "-port.grpc=19333"
      "-mdir=${dataDir}/master"
      "-defaultReplication=000"
      "-volumeSizeLimitMB=1024"
      "-telemetry=false"
    ];
  };

  systemd.services.seaweedfs-volume = service {
    description = "SeaweedFS cache volumes";
    subdir = "volume";
    dependencies = [ "seaweedfs-master.service" ];
    args = [
      "volume"
      "-ip=127.0.0.1"
      "-ip.bind=127.0.0.1"
      "-port=8080"
      "-port.grpc=18080"
      "-master=127.0.0.1:9333"
      "-dir=${dataDir}/volume"
      "-max=256"
    ];
  };

  systemd.services.seaweedfs-filer = service {
    description = "SeaweedFS cache metadata";
    subdir = "filer";
    dependencies = [
      "seaweedfs-master.service"
      "seaweedfs-volume.service"
    ];
    args = [
      "filer"
      "-ip=127.0.0.1"
      "-ip.bind=127.0.0.1"
      "-port=8888"
      "-port.grpc=18888"
      "-master=127.0.0.1:9333"
      "-localSocket=/run/seaweedfs-filer/filer.sock"
    ];
    extraServiceConfig = {
      RuntimeDirectory = "seaweedfs-filer";
      RuntimeDirectoryMode = "0700";
      ExecStartPost = "${pkgs.python3}/bin/python3 ${./seaweedfs-init.py} ${weed}";
      TimeoutStartSec = 150;
    };
  };

  systemd.services.seaweedfs-s3 = service {
    description = "SeaweedFS authenticated HTTPS cache";
    subdir = "s3";
    dependencies = [ "seaweedfs-filer.service" ];
    preStart = ''
      ${pkgs.python3}/bin/python3 ${./seaweedfs-auth.py} \
        "$CREDENTIALS_DIRECTORY/aws-credentials" /run/seaweedfs-s3/s3.json
    '';
    args = [
      "s3"
      "-filer=127.0.0.1:8888"
      "-ip.bind=0.0.0.0"
      "-port=${toString s3Port}"
      "-port.grpc=19002"
      "-config=/run/seaweedfs-s3/s3.json"
      # With cert/key and no separate HTTPS port, -port serves HTTPS only.
      "-cert.file=%d/tls.crt"
      "-key.file=%d/tls.key"
      "-localSocket=/run/seaweedfs-s3/s3.sock"
      "-iam=false"
      "-port.iceberg=0"
      "-port.lance=0"
    ];
    extraServiceConfig = {
      RuntimeDirectory = "seaweedfs-s3";
      RuntimeDirectoryMode = "0700";
      # PID 1 reads root-owned material; the service receives private copies.
      # These TLS files remain shared with RustFS until its retirement.
      LoadCredential = [
        "aws-credentials:/persist/secrets/sccache/aws-credentials"
        "tls.crt:/persist/secrets/rustfs-tls/rustfs_cert.pem"
        "tls.key:/persist/secrets/rustfs-tls/rustfs_key.pem"
      ];
    };
  };
}
