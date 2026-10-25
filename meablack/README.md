# meablack: installation and recovery

Draft plan: x86_64, UEFI, Intel CPU, NVIDIA RTX 3060 12 GB, single SSD, DHCP,
encrypted ext4 root, zram, and SSH. The custom USB installer automatically
erases the sole internal disk and installs a prebuilt system without network
access or prompts. Strata comes later, after placing the machine on the LAN.

## Build the unattended USB

On an internet-connected x86_64 Linux machine with Nix, flakes, OpenSSL and
OpenSSH installed:

```sh
git clone https://github.com/mitschwimmer/nix-config
cd nix-config
export MEABLACK_RECOVERY_PASSPHRASE_FILE="$HOME/meablack-recovery-passphrase"
bash meablack/build-installer.sh
```

The build helper creates a random 256-bit passphrase if the specified file does
not exist, then reuses that file for subsequent builds. Store it outside this
checkout and back it up. The helper displays the fingerprints of the bundled
public SSH keys; review `meablack/authorized_keys` before building. They were
retrieved from `https://github.com/mitschwimmer.keys` on 2026-10-25:

```text
RSA     SHA256:sbdpCKGbLvgwUa9sLxjwlkC00LT11UczbxdyfAapves
ED25519 SHA256:CnvyuZXJ7f4QgsCqFRotdWBJmh7zJiHrTKhkD89Ut6k
```

The image includes the target system closure, NVIDIA driver, firmware, a
prebuilt Disko script, installation tools and public SSH keys. No GitHub access,
flake evaluation, package downloads or compilation happens during installation.
The installer disables DHCP, Wi-Fi, NetworkManager, SSH and binary caches.
The installed system retains DHCP and SSH for its eventual LAN connection.

**The ISO, USB and build machine's Nix store contain the recovery passphrase in
plaintext.** Anyone possessing the image can unlock the resulting disk. Do not
publish the image or build it on a shared/remote builder. Building the ordinary
`meablack` system does not include the passphrase. Keep a separate copy of the
passphrase; do not depend on the USB as its only backup.

Write the ISO to the **whole USB device**, replacing the example path:

```sh
sudo dd if=result/iso/meablack-unattended.iso of=/dev/disk/by-id/USB-DEVICE bs=4M conv=fsync status=progress
```

This also erases the selected USB. The installer supports booting the directly
written ISO; Ventoy, copied ISO files, PXE and booting the ISO from the target
disk are not supported.

## Unattended installation

Boot the USB in UEFI mode. Disable Secure Boot in firmware if necessary to boot
this unsigned installer. There is a one-second boot menu and **no installation
confirmation or disk-specific allowlist**. Every boot repeats the installation.

The boot service:

1. Requires exactly one writable, non-removable, non-USB whole disk and checks
   that it is not an ancestor of the live ISO device. It stops if discovery is
   ambiguous or the live medium cannot be identified.
2. Erases that disk and creates a 1 GiB EFI partition and LUKS2-encrypted ext4
   root. The bundled random passphrase initializes LUKS without prompts.
3. Installs the prebuilt system with systemd-boot and your pinned SSH keys.
4. Attempts TPM2 enrollment against the **current PCR 7 policy**, retaining the
   passphrase slot. With supported TPM2 hardware this permits automatic disk
   unlock. Without it, enter the saved passphrase at the next disk boot.
5. Flushes and unmounts the disk, closes LUKS and powers off on success.

**Remove the USB before powering on again.** Leaving it attached and booting it
again will erase and reinstall the disk again. This USB will also erase another
computer's sole eligible internal disk if booted there.

The system can boot before being connected to the LAN. Once connected, use
`ssh root@<DHCP-address>` with one of the bundled keys. Password SSH is disabled.
No Strata runtime, model weights or API service are installed.

On failure the installer stays powered on, without an automatic retry or
reboot. At the live console inspect:

```sh
systemctl status install-meablack
journalctl -b -u install-meablack
lsblk -f
lspci -nnk
```

Fix the configuration, rebuild/rewrite the USB, and boot it again for a clean
retry. Logs live in the installer session and are lost on poweroff. A successful
install should still be verified with an actual disk boot: an installation
command succeeding does not prove hardware compatibility.

To recover the passphrase from the USB on another Linux machine, mount its ISO
filesystem read-only and read `/meablack-recovery-passphrase` on that mount. It
is a 64-character hex string with no trailing newline and can be typed at the
LUKS prompt. Keep that medium disconnected during ordinary operation.

## Important limitations

- The EFI System Partition is unencrypted. LUKS2 covers the ext4 root.
- The first installation deliberately uses **systemd-boot**, not Lanzaboote:
  switching firmware keys remotely without physical recovery access risks an
  unbootable machine.
- The unattended installer initializes LUKS with its bundled random passphrase
  and attempts TPM2 enrollment. Preserve the passphrase offline. Re-enroll TPM2
  after any later Secure Boot policy change.
- TPM PCR 7 binds to Secure Boot policy, but it does not by itself attest the
  entire operating system. TPM-only automatic unlock is not equivalent to a PIN.
- A Secure Boot firmware update/key change may require LUKS recovery.
- NVIDIA RTX 3060 driver is enabled at first boot using
  the stable NVIDIA driver and its supported open kernel module. This requires
  unfree package evaluation and a working kernel/driver combination.
- No machine-specific NIC or storage driver information is available yet.
- The placeholder disk device in `disko.nix` is used only for the ordinary host
  configuration. The offline formatting script overrides it with a runtime
  alias to the detected disk; the installed system uses stable partition labels.

## Strata inference runtime

Strata is provisioned after the first boot, **not downloaded or executed by
NixOS activation or as root**. The host includes the NVIDIA driver and
`programs.nix-ld` for running third-party dynamically linked Linux binaries.

1. Log in as a dedicated unprivileged user (create one with persistent home
   directory and SSH access before provisioning).
2. Verify the GPU and driver: `nvidia-smi`. Upstream Strata currently
   recommends NVIDIA driver 580 or newer.
3. Review the upstream installation process and select a particular release:
   https://github.com/Niko1221/Strata/blob/main/docs/INSTALL.md
4. Install the Strata Terminal under that user and run `strata launch`
   interactively to select a model and configure network binding. Avoid running
   `curl | sh` without reviewing the script and verifying the release.
5. The terminal/runtime is managed upstream, not reproducibly by this NixOS
   flake. If NixOS runtime compatibility fails, inspect missing dynamic library
   dependencies rather than creating broad global library paths.
6. Keep Strata on loopback initially; set firewall/API authentication
   deliberately before allowing LAN access. Model weights require substantial
   disk capacity (tens of GB).

This PR intentionally does **not** install an automatically updating binary,
publish an inference API, or create an unverified systemd service.

## Hardware checks and manual installation

The automated path assumes x86_64 UEFI, Intel CPU, NVIDIA RTX 3060, a single
internal disk, and storage supported by the configured initrd modules. Inspect
`lspci -nnk` from the live console if a driver is missing and include it before
rebuilding. The installer does not generate an unknown hardware configuration
or fetch drivers from the network.

For manual installation from a networked installer, use the pinned Disko
installer and explicitly supply the actual whole-disk by-id path. The normal
host configuration retains an interactive LUKS prompt. The offline USB uses
its prebuilt formatting script instead of evaluating `disko-install` at boot.

## Recovery and TPM enrollment (after first successful boot)

Identify the real LUKS partition, e.g. with `lsblk -f`, rather than copying
a device name from this document. Verify a working LUKS passphrase and a
physical recovery console. Create a **separate offline recovery key**:

```sh
sudo systemd-cryptenroll --recovery-key /dev/disk/by-id/DISK-PARTITION
```

Record the recovery key OFFLINE and test it before removing any other key
slots. The USB already attempted enrollment for the initial policy. After establishing
the final Secure Boot policy, replace that TPM2 binding (this retains the
passphrase and recovery slots):

```sh
sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 --wipe-slot=tpm2 /dev/disk/by-id/DISK-PARTITION
```

The `tpm2-device=auto` crypttab option is already configured declaratively.
Test both automatic unlock and recovery-key fallback with console access.
Never wipe the passphrase or recovery key slot as part of provisioning.

## Secure Boot staged migration

Read the current [Lanzaboote guide](https://nix-community.github.io/lanzaboote/)
for hardware-specific caveats. With a working systemd-boot installation,
physical recovery access, and verified backups:

1. Inspect `bootctl status` and firmware Secure Boot status.
2. Generate signing keys using `sudo sbctl create-keys`. Back up the private
   keys from `/var/lib/sbctl` securely **outside this disk**, never in Git.
3. Add `./secure-boot.nix` to the `meablack` imports and rebuild. This requires
   the `lanzaboote` flake input/module already present in `flake.nix`.
4. Confirm signed boot artifacts and follow firmware-specific instructions
   to enter Setup Mode. Enroll your keys with `sbctl enroll-keys`; depending
   on hardware option ROMs, Microsoft/firmware keys may need retention.
   **Do not clear keys blindly or do this remotely.**
5. Enable Secure Boot, reboot at the console, verify `bootctl status` and
   `sbctl verify`, and only then enroll the TPM token using PCR 7.
6. Test at least one unattended reboot and one recovery-key boot.

This is a *manual cutover*, not an installation-time automatic firmware change.

## Recovery

If unattended TPM unlock fails, use the local LUKS passphrase or offline
recovery key at the initrd prompt. If the boot chain is broken, use a trusted
USB installer with physical access: unlock the LUKS volume with `cryptsetup
open`, mount ext4 and the EFI partition, and repair or roll back the bootloader
or configuration. If firmware Secure Boot rejects the bootloader, restore the
known-good firmware key state or temporarily disable verification through
authorized firmware controls before recovering. Preserve the signed boot
keys, LUKS header backup, recovery key, and a bootable installer offline.

After firmware/DB updates affecting PCR 7, unlock with the recovery key and
re-enroll TPM2. Do not erase old slots until recovery is verified.

## Validation

`python3 meablack/test-select-disk.py` exercises disk discovery with mocked
commands: SATA/NVMe/virtual disks, USB exclusion, read-only/removable disks,
ambiguous targets, unknown live media, and installer-ancestor rejection. No test
accesses or formats real devices. CI checks Bash/ShellCheck, evaluates and builds
the host with the committed lock, and builds the ISO with a disposable random
CI passphrase. CI does not publish that image.

Before using the installer on hardware, boot a locally built ISO in an isolated
UEFI VM with **no virtual NIC**, one blank SATA/NVMe disk and the ISO as CD-ROM.
It should install and power off. Remove the ISO, boot the disk, and verify LUKS
unlock using the saved passphrase and a running NixOS system. With a virtual
TPM, verify automatic unlock too. A second boot of the ISO must reinstall rather
than depend on state left by the first run. No-network installation and disk
boot are separate checks; an ISO build alone does not cover either.

Physical validation still includes the actual storage/NIC drivers, TPM2 and
firmware-specific Secure Boot enrollment. Initial installation deliberately
leaves firmware Secure Boot keys unchanged.
