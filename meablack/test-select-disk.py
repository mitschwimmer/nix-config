"""Exercise destructive-install disk selection without accessing real devices."""

import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


def disk(name, transport="sata", removable=False, readonly=False, kind="disk"):
    return dict(name=name, type=kind, tran=transport, rm=removable, ro=readonly)


class SelectionTest(unittest.TestCase):
    def select(self, devices, ancestors="/dev/sdb1\n/dev/sdb", iso="/dev/sdb1", udev_status=0):
        with tempfile.TemporaryDirectory() as directory:
            mocks = {
                "udevadm": '#!/bin/bash\nexit "$UDEV_STATUS"\n',
                "findmnt": '#!/bin/bash\nprintf "%s\\n" "$MOCK_ISO"\n',
                "lsblk": '''#!/bin/bash
if [[ $1 == --json ]]; then
    printf '%s\\n' "$MOCK_DISKS"
elif [[ $1 == --inverse ]]; then
    printf '%s\\n' "$MOCK_ANCESTORS"
fi
''',
            }
            for name, content in mocks.items():
                file = Path(directory, name)
                file.write_text(content)
                file.chmod(0o755)
            environment = os.environ | {
                "PATH": directory + os.pathsep + os.environ["PATH"],
                "MOCK_DISKS": json.dumps(dict(blockdevices=devices)),
                "MOCK_ANCESTORS": ancestors,
                "MOCK_ISO": iso,
                "UDEV_STATUS": str(udev_status),
            }
            return subprocess.run(
                ["bash", "-c", '''
set -euo pipefail
# No real block devices are inspected. Only the mock ISO is a block device.
test() {
    if [[ $1 == -b ]]; then
        [[ $2 == /dev/sdb1 ]]
    else
        builtin test "$@"
    fi
}
source "$1"
''', "test", str(Path(__file__).with_name("select-disk.sh"))],
                env=environment, capture_output=True, text=True,
            )

    def test_sata_disk_and_usb_installer(self):
        result = self.select([disk("/dev/sda"), disk("/dev/sdb", "usb")])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "/dev/sda\n")

    def test_nvme_disk_and_removable_usb(self):
        result = self.select([
            disk("/dev/nvme0n1", "nvme"), disk("/dev/sdb", "usb", removable=True),
        ])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "/dev/nvme0n1\n")

    def test_virtual_disk_with_no_transport(self):
        result = self.select([disk("/dev/vda", None), disk("/dev/sr0", kind="rom")])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "/dev/vda\n")

    def test_multiple_internal_disks(self):
        self.assertNotEqual(self.select([disk("/dev/sda"), disk("/dev/nvme0n1")]).returncode, 0)

    def test_no_internal_disk(self):
        self.assertNotEqual(self.select([disk("/dev/sdb", "usb")]).returncode, 0)

    def test_removable_or_readonly_disks_are_excluded(self):
        result = self.select([
            disk("/dev/sda"), disk("/dev/sdc", removable=True), disk("/dev/sdd", readonly=True),
        ])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "/dev/sda\n")

    def test_installer_misreported_as_internal(self):
        result = self.select([disk("/dev/sdb")])
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("contains the installer", result.stderr)

    def test_unknown_installer_source(self):
        self.assertNotEqual(self.select([disk("/dev/sda")], iso="overlay").returncode, 0)

    def test_exact_ancestor_match(self):
        result = self.select([disk("/dev/sdb2")])
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_udev_failure_stops_discovery(self):
        self.assertNotEqual(self.select([disk("/dev/sda")], udev_status=1).returncode, 0)


if __name__ == "__main__":
    unittest.main()
