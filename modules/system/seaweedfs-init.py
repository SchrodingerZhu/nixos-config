"""Initialize missing cache buckets and bounded, synchronous volume growth."""

import json
import subprocess
import sys
import time
import urllib.error
import urllib.request


def read_filer(path):
    request = urllib.request.Request(
        "http://127.0.0.1:8888" + path, headers={"Accept": "application/json"}
    )
    try:
        with urllib.request.urlopen(request, timeout=5) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        if error.code == 404:
            return None
        raise


def configured():
    settings = read_filer("/etc/seaweedfs/filer.conf")
    return settings is not None and any(
        location.get("locationPrefix") == "/buckets/"
        and location.get("volumeGrowthCount") == 1
        and location.get("fsync") is True
        and location.get("replication") == "000"
        for location in settings.get("locations", [])
    )


def check_volume_registration():
    def status(url):
        with urllib.request.urlopen(url, timeout=5) as response:
            return json.load(response)

    local = status("http://127.0.0.1:8080/status")
    topology = status("http://127.0.0.1:9333/dir/status")["Topology"]
    expected = len(local.get("Volumes") or [])
    for data_center in topology.get("DataCenters") or []:
        for rack in data_center.get("Racks") or []:
            for node in rack.get("DataNodes") or []:
                if node.get("Url") == "127.0.0.1:8080":
                    if node.get("Volumes") == expected:
                        return
    raise RuntimeError("The master has not registered all local volumes yet")


def initialize(weed):
    # A missing config is normal on a fresh dataset; an unreachable filer is not.
    if read_filer("/?limit=1") is None:
        raise RuntimeError("Filer root is not ready")
    # Filer metadata may be ready before the volume server's first heartbeat.
    # Wait for the data path too, before allowing the S3 service to start.
    check_volume_registration()
    commands = []
    if not configured():
        commands.append(
            "fs.configure -locationPrefix=/buckets/ -replication=000 "
            "-volumeGrowthCount=1 -fsync -apply"
        )
    for bucket in ("sccache", "nix-cache"):
        if read_filer(f"/buckets/{bucket}/?limit=1") is None:
            commands.append(f"s3.bucket.create -name={bucket} -owner=fleet-cache")
    if commands:
        subprocess.run(
            [weed, "shell", "-master=127.0.0.1:9333", "-filer=127.0.0.1:8888"],
            input="\n".join(commands) + "\n", text=True,
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            check=True, timeout=15,
        )
    # weed shell may exit successfully after an individual command fails.
    if not configured():
        raise RuntimeError("Cache path settings were not applied")
    for bucket in ("sccache", "nix-cache"):
        if read_filer(f"/buckets/{bucket}/?limit=1") is None:
            raise RuntimeError(f"Cache bucket {bucket} was not created")


def main():
    deadline = time.monotonic() + 120
    while True:
        try:
            initialize(sys.argv[1])
            return
        except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
            if time.monotonic() >= deadline:
                raise RuntimeError("SeaweedFS cache initialization failed") from error
            time.sleep(2)


if __name__ == "__main__":
    main()
