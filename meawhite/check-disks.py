"""Read-only preflight. No formatting commands belong in this file."""
import json
import os
from pathlib import Path
import stat
import subprocess
import sys


IDS = (
    "nvme-eui.002538a4514017bc",
    "wwn-0x5000c5009dcaa25a",
    "wwn-0x5000c5009dccc120",
)


def descendants(device):
    yield device
    for child in device.get("children", []):
        yield from descendants(child)


def validate(devices, targets, live_ancestors, holders):
    if not live_ancestors:
        raise ValueError("Cannot identify installer ancestors")
    if len(targets) != 3 or len(set(targets)) != 3:
        raise ValueError("Expected three distinct allowlisted disks")
    for target in targets:
        matches = [d for d in devices if d["name"] == target]
        if len(matches) != 1:
            raise ValueError(f"Missing or ambiguous disk: {target}")
        disk = matches[0]
        if disk["type"] != "disk" or disk["ro"] or disk["rm"] or disk.get("tran") == "usb":
            raise ValueError(f"Not a writable internal whole disk: {target}")
        if target in live_ancestors:
            raise ValueError(f"Disk contains installer: {target}")
        for child in descendants(disk):
            if any(child.get("mountpoints") or []) or holders.get(child["name"]):
                raise ValueError(f"Mounted, swap or active device: {child['name']}")


def output(*args):
    return subprocess.check_output(args, text=True).strip()


def main():
    subprocess.run(["udevadm", "settle"], check=True)
    targets = []
    for identifier in IDS:
        path = Path("/dev/disk/by-id") / identifier
        resolved = path.resolve(strict=True)
        if not stat.S_ISBLK(resolved.stat().st_mode):
            raise ValueError(f"Not a block device: {path}")
        targets.append(str(resolved))
    source = output("findmnt", "--noheadings", "--raw", "--output", "SOURCE", "/iso")
    if not stat.S_ISBLK(os.stat(source).st_mode):
        raise ValueError("Installer must be booted from a directly written ISO")
    ancestors = output("lsblk", "--inverse", "--noheadings", "--raw", "--paths",
                       "--output", "NAME", source).splitlines()
    devices = json.loads(output("lsblk", "--json", "--bytes", "--paths", "--output",
                                "NAME,TYPE,TRAN,RM,RO,MOUNTPOINTS"))["blockdevices"]
    holders = {}
    for disk in devices:
        for child in descendants(disk):
            holder_path = Path("/sys/class/block") / Path(child["name"]).name / "holders"
            holders[child["name"]] = list(holder_path.iterdir())
    validate(devices, targets, ancestors, holders)
    print("Validated installation targets:", *targets, sep="\n", file=sys.stderr)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        sys.exit(f"Refusing installation: {error}")
