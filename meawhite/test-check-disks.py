"""Exercise destructive-installation guards without touching block devices."""
import copy
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location("check_disks", Path(__file__).with_name("check-disks.py"))
check = importlib.util.module_from_spec(spec)
spec.loader.exec_module(check)


class PreflightTests(unittest.TestCase):
    def setUp(self):
        self.targets = ["/dev/nvme0n1", "/dev/sda", "/dev/sdb"]
        self.disks = [dict(name=name, type="disk", ro=False, rm=False,
                           tran="nvme" if "nvme" in name else "sata",
                           mountpoints=[None]) for name in self.targets]
        self.live = ["/dev/sdc1", "/dev/sdc"]
        self.holders = {}

    def validate(self):
        check.validate(self.disks, self.targets, self.live, self.holders)

    def test_valid_targets(self):
        self.validate()

    def test_unrelated_extra_disk_is_not_selected(self):
        self.disks.append(dict(name="/dev/sdd", type="disk", ro=False, rm=False))
        self.validate()

    def test_missing_disk(self):
        self.disks.pop()
        with self.assertRaises(ValueError):
            self.validate()

    def test_duplicate_targets(self):
        self.targets[2] = self.targets[1]
        with self.assertRaises(ValueError):
            self.validate()

    def test_bad_disk_properties(self):
        for field, value in [("type", "part"), ("ro", True), ("rm", True), ("tran", "usb")]:
            with self.subTest(field=field):
                disks = copy.deepcopy(self.disks)
                disks[0][field] = value
                with self.assertRaises(ValueError):
                    check.validate(disks, self.targets, self.live, {})

    def test_installer_ancestor_even_without_usb_transport(self):
        self.live.append(self.targets[0])
        with self.assertRaises(ValueError):
            self.validate()

    def test_unknown_installer(self):
        self.live = []
        with self.assertRaises(ValueError):
            self.validate()

    def test_mounted_partition_or_swap(self):
        for mountpoint in ["/iso", "/mnt", "[SWAP]"]:
            with self.subTest(mountpoint=mountpoint):
                self.disks[0]["children"] = [dict(name="/dev/nvme0n1p1", mountpoints=[mountpoint])]
                with self.assertRaises(ValueError):
                    self.validate()

    def test_active_luks_raid_or_zfs_holder(self):
        self.disks[1]["children"] = [dict(name="/dev/sda1", mountpoints=[None])]
        self.holders["/dev/sda1"] = ["md127"]
        with self.assertRaises(ValueError):
            self.validate()

    def test_ambiguous_inventory(self):
        self.disks.append(copy.deepcopy(self.disks[0]))
        with self.assertRaises(ValueError):
            self.validate()


if __name__ == "__main__":
    unittest.main()
