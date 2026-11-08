# meawhite: installation and recovery

ASRock B860I WiFi, Intel Core Ultra 5 235, 32 GiB RAM, Intel integrated
graphics and AMD RX 9060 XT. Ethernet uses the e1000e/r8169 kernel drivers.
The host provides DHCP, key-only root SSH, zram and administration tools.
No Strata user, inference stack, VFIO configuration or API firewall opening
is included. No desktop or network file sharing service is configured.

## Storage

| Role | Allowlisted /dev/disk/by-id device | Layout |
| --- | --- | --- |
| System | nvme-eui.002538a4514017bc | 1 GiB EFI, remaining space LUKS2/ext4 at / |
| Data member 1 | wwn-0x5000c5009dcaa25a | GPT partition, RAID1 member |
| Data member 2 | wwn-0x5000c5009dccc120 | GPT partition, RAID1 member |

The two HDDs form `/dev/md/meawhite-data` (Linux mdadm RAID1). LUKS2
encrypts the array, with ext4 at `/data` and about 3.6 TiB usable capacity.
Both root and data use TPM2 auto-unlock and retain the same independent
256-bit recovery passphrase. A mirror protects against one HDD failure;
keep separate backups. Initial RAID synchronization continues after installation.

The unattended installer **erases all three listed disks**, including IncusOS,
its instances, ZFS pools and all other data. It requires the exact three disk
identities; other disks are not formatting targets. It rejects missing,
duplicate, read-only, removable, USB, mounted or active target devices and any
target containing the live ISO. Failed preflight causes no formatting.
Existing active arrays/mappings cause a refusal rather than being stopped
automatically. Installation failure leaves the machine powered on; no retry.

## Build the offline USB

On a private, internet-connected x86_64 Linux build machine with Nix, flakes,
OpenSSL and OpenSSH installed:

```sh
git clone https://github.com/mitschwimmer/nix-config
cd nix-config
export MEAWHITE_RECOVERY_PASSPHRASE_FILE="$HOME/meawhite-recovery-passphrase"
bash meawhite/build-installer.sh
```

The helper generates the passphrase once, outside the checkout, and reuses it.
Back it up separately. Review the printed SSH fingerprints and
`meawhite/authorized_keys`; these are a separate copy of the meablack keys.
No meablack file or installer is reused at runtime.

**The passphrase is plaintext on the ISO, USB and in the build machine's Nix
store. Keep all three private. Do not publish CI-built ISOs.** The installed
host closure does not contain this passphrase. From another computer the USB
file `/meawhite-recovery-passphrase` contains the 64 lowercase hex characters
with no newline; do not depend on the USB as the only recovery copy.

Write to the whole USB device (this erases that USB):

```sh
sudo dd if=result/iso/meawhite-unattended.iso of=/dev/disk/by-id/USB-DEVICE bs=4M conv=fsync status=progress
```

Use a directly written ISO; Ventoy, loop-mounted ISO files and PXE are not
supported. The ISO bundles the complete target closure and formatting tools.
Networking and SSH are disabled in the installer, so installation works offline.

## Firmware and installation

IncusOS currently runs with UEFI Secure Boot and TPM. Its existing trust keys
do not imply trust in this NixOS USB or a new NixOS bootloader.

1. Temporarily disable Secure Boot in firmware, retaining the existing keys.
   Do not clear the TPM or firmware keys for this installation.
2. Boot the USB in UEFI mode. After one second it starts without confirmation,
   validates disk identities, erases the three target disks and installs.
3. The installer enrolls both LUKS volumes against the current TPM PCR 7 policy,
   retaining passphrase recovery, then unmounts and powers off.
4. Remove the USB before powering on. Every USB boot repeats the erasure.
5. Verify disk boot and TPM unlock, then connect Ethernet and use
   `ssh root@<DHCP-address>`. SSH password login is disabled.

If TPM enrollment fails, the installer reports it and keeps passphrase boot
available. Enter the recovery passphrase at the console for each required
volume. A later Secure Boot policy change requires TPM re-enrollment.

For installer errors, inspect the physical console:

```sh
systemctl status install-meawhite
journalctl -b -u install-meawhite
lsblk -f
cat /proc/mdstat
```

## Enable Secure Boot after verified disk boot

With physical console access and tested LUKS recovery, follow the upstream
[Lanzaboote guide](https://nix-community.github.io/lanzaboote/) for firmware key
enrollment. Generate signing keys with `sbctl create-keys`, back up
`/var/lib/sbctl` securely outside the server, then build signed boot artifacts:

```sh
nixos-rebuild switch --flake github:mitschwimmer/nix-config#meawhite-secure
sbctl verify
```

Only after verifying signed artifacts, enroll the keys following the guide
and motherboard-specific instructions, retaining Microsoft/firmware trust as
needed by option ROMs. Enable Secure Boot and reboot at the console. The old
TPM policy may require the saved passphrase for **both** encrypted volumes.
Verify `bootctl status`, then renew both TPM bindings under the final policy:

```sh
systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 --wipe-slot=tpm2 /dev/disk/by-partlabel/disk-main-root
systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 --wipe-slot=tpm2 /dev/md/meawhite-data
```

These commands prompt for the existing passphrase; keep its slot. Test automatic
reboot and passphrase recovery. Continue using `#meawhite-secure` for subsequent
rebuilds; `#meawhite` is the unsigned bootstrap profile. PCR 7 binds to Secure
Boot policy, not the entire OS, and automatic TPM unlock is not a PIN.

## Verify and recover

```sh
findmnt --target /
findmnt --target /data
cat /proc/mdstat
mdadm --detail /dev/md/meawhite-data
cryptsetup status cryptroot
cryptsetup status cryptdata
```

Wait for RAID synchronization and verify two active members before relying on
the mirror. Replacement HDD identities require updating `disko.nix` and the
installer allowlist; replace/rebuild a failed member manually, never by booting
the destructive installer. Do not rerun Disko on an existing data array.

Use a separate ordinary NixOS rescue USB for repairs. To use this USB without
erasure, append `systemd.mask=install-meawhite.service` to its boot entry.
Preserve the passphrase, LUKS header backups and Secure Boot signing keys offline.

## Validation

`python3 meawhite/test-check-disks.py` checks disk safety decisions with synthetic
inventories; it never accesses or formats a block device. CI checks Bash and
ShellCheck, builds both host profiles and builds an offline ISO using a disposable
passphrase without publishing it.

Before hardware use, test the install/boot sequence in an isolated UEFI VM with
no NIC, three blank disks, matching test-only disk identities and a virtual TPM.
Remove the ISO, verify both mounts, TPM and recovery unlock, full mirror sync and
degraded operation with one HDD absent. The production image intentionally
refuses generic VM disk identities. Builds and mocked tests do not prove this
boot sequence or compatibility with the physical motherboard.
