"""Translate the shared AWS profile into a private SeaweedFS identity file."""

import configparser
import json
import os
import sys


def main():
    source, target = sys.argv[1:]
    profile = configparser.ConfigParser(interpolation=None)
    with open(source) as stream:
        profile.read_file(stream)
    access_key = profile.get("default", "aws_access_key_id").strip()
    secret_key = profile.get("default", "aws_secret_access_key").strip()
    if not access_key or not secret_key:
        raise ValueError("The shared cache credentials must be nonempty")
    identity = {
        "name": "fleet-cache",
        "credentials": [{"accessKey": access_key, "secretKey": secret_key}],
        "actions": [
            f"{action}:{bucket}"
            for bucket in ("sccache", "nix-cache")
            for action in ("Read", "Write", "List", "Tagging")
        ],
    }
    temporary = target + ".tmp"
    descriptor = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    os.fchmod(descriptor, 0o600)
    with os.fdopen(descriptor, "w") as stream:
        json.dump({"identities": [identity]}, stream)
    os.replace(temporary, target)


if __name__ == "__main__":
    main()
