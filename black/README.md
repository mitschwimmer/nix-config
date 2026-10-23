# black: installation and recovery

Draft plan: x86_64, UEFI, Intel CPU, NVIDIA RTX 3060 12 GB, single SSD, DHCP,
encrypted ext4 root, zram, and SSH. **This is not a one-command unattended
installation.** The machine model, TPM2 availability, firmware enrollment
mechanism, NIC driver, and actual target disk must be checked locally.

## Important limitations

- The EFI System Partition is unencrypted. LUKS2 covers the ext4 root.
- The first installation deliberately uses **systemd-boot**, not Lanzaboote:
  switching firmware keys remotely without physical recovery access risks an
  unbootable machine.
- LUKS is initialized with a passphrase. The TPM2 token is enrolled separately
  **after** the system boots; the recovery secret must be retained offline.
- TPM PCR 7 binds to Secure Boot policy, but it does not by itself attest the
  entire operating system. TPM-only automatic unlock is not equivalent to a PIN.
- A Secure Boot firmware update/key change may require LUKS recovery.
- NVIDIA RTX 3060 proprietary-driver package is enabled at first boot using
  the stable NVIDIA driver and its supported open kernel module. This requires
  unfree package evaluation and a working kernel/driver combination.
- No machine-specific NIC or storage driver information is available yet.
- The placeholder disk device in `disko.nix` must never be used literally.

## Preflight

Boot a compatible NixOS installer via UEFI with physical console access.
Temporarily disable Secure Boot *only if the installer is not trusted by the
current firmware*. Re-enable Secure Boot only after the signed-boot migration.

Inspect:

```sh
test -d /sys/firmware/efi
lsblk -o NAME,SIZE,MODEL,SERIAL,TRAN,PATH
ls -l /dev/disk/by-id/
lspci -nnk
bootctl status
systemd-cryptenroll --tpm2-device=list
```

Confirm which **entire disk** may be erased. Have local keyboard/display or
out-of-band management access before proceeding. Back up all existing data.

## Installation

On the installer, clone the repository and review the chosen disk ID:

```sh
git clone https://github.com/mitschwimmer/nix-config
cd nix-config
sudo disko-install --flake .#black --disk main /dev/disk/by-id/ACTUAL-DISK-ID
```

Disko formatting **irreversibly erases** the target disk. Follow interactive
LUKS passphrase prompts. `disko-install` is supplied by the disko installer
package, not necessarily the default NixOS ISO. Use a custom ISO with it or
`nix run github:nix-community/disko#disko-install -- ...` and check supported
CLI flags against the pinned disko revision before running.

**Before the first reboot**, install authorized public keys in the target root.
This is an explicit provisioning step rather than an unpinned network fetch
embedded in Nix evaluation. Review the key fingerprints out of band.

```sh
sudo install -d -m 0755 /mnt/etc/ssh/authorized_keys.d
curl -fsSL https://github.com/mitschwimmer.keys | sudo tee /mnt/etc/ssh/authorized_keys.d/root
sudo chmod 0644 /mnt/etc/ssh/authorized_keys.d/root
sudo test -s /mnt/etc/ssh/authorized_keys.d/root
```

Check the actual root mount location after disko-install; if it unmounts
`/mnt`, mount the new root again before writing keys. Verify the keys and
test SSH access before relying on remote administration. Never assume the GitHub
account has an active key.

## TPM enrollment (after first successful boot)

Identify the real LUKS partition, e.g. with `lsblk -f`, rather than copying
a device name from this document. Verify a working LUKS passphrase and a
physical recovery console. Create a **separate offline recovery key**:

```sh
sudo systemd-cryptenroll --recovery-key /dev/disk/by-id/DISK-PARTITION
```

Record the recovery key OFFLINE and test it before removing any other key
slots. Only after the machine's final Secure Boot policy is established, enroll
the TPM2 binding:

```sh
sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 /dev/disk/by-id/DISK-PARTITION
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
3. Add `./secure-boot.nix` to the `black` imports and rebuild. This requires
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

## Validation before merge

- [ ] Confirm TPM2 is available, firmware permits safe custom key enrollment.
- [ ] Confirm the actual SSD by-id path and ethernet kernel driver.
- [ ] Confirm GitHub key fingerprints and bootstrapped root SSH.
- [ ] GitHub Actions `black NixOS build` succeeds (evaluation and system build).
- [ ] Commit a regenerated `flake.lock` with Disko and Lanzaboote pins; CI currently resolves missing inputs.
- [ ] Confirm `disko-install` CLI against the locked disko revision.
- [ ] Perform the initial installation and secure-boot cutover with console access.
