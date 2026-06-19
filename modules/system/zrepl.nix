# Snapshots via zrepl: a single LOCAL snap+prune job (no replication, no
# monitoring/Prometheus, no send jobs). Snapshots only the persistent
# data-bearing datasets (home, persist) -- NOT the ephemeral root, NOT nix.
{ ... }:
{
  services.zrepl = {
    enable = true;
    settings.jobs = [
      {
        name = "snap_local";
        type = "snap";
        filesystems = {
          "rpool/safe/home" = true;
          "rpool/safe/persist" = true;
        };
        snapshotting = {
          type = "periodic";
          prefix = "zrepl_";
          interval = "15m";
        };
        pruning.keep = [
          # Protect manual (non-zrepl_) snapshots from pruning.
          {
            type = "regex";
            negate = true;
            regex = "^zrepl_";
          }
          # GFS retention grid for zrepl_ snapshots:
          # keep all within the last hour, then hourly/daily/weekly thinning.
          {
            type = "grid";
            grid = "1x1h(keep=all) | 24x1h | 14x1d | 8x7d";
            regex = "^zrepl_";
          }
        ];
      }
    ];
  };
}
