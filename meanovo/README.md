# meanovo: staged boot, Secure Boot and TPM2 unlock

The normal `meanovo` flake output keeps the existing systemd-boot and passphrase
unlock. The separate `meanovo-secure` output uses Lanzaboote with signed
boot artifacts and enables systemd TPM2 unlock for **both** encrypted devices:

| Mapping | LUKS block device |
| --- | --- |
| `encrypted_root` | `/dev/disk/by-uuid/247a442b-20ea-42ef-a41c-45450c070c06` |
| `encrypted_swap` | `/dev/disk/by-uuid/0a995aba-d644-44fe-a86e-38ae467ccbfa` |

The UUIDs come from `meanovo/hardware-configuration.nix`; confirm they still
identify the intended LUKS containers before running any enrollment command.
The configuration does **not** format disks, replace key slots, enroll TPM
secrets or modify firmware Secure Boot keys automatically.

## Stage 0 — verify prerequisites and recovery

**Test SDDM separately first.** Changing the display manager and bootloader
at once makes it harder to diagnose an unsuccessful first boot.

At the physical machine (with a trusted rescue USB available):

```sh
bootctl status
sudo sbctl status
lsblk -f
sudo cryptsetup luksDump /dev/disk/by-uuid/247a442b-20ea-42ef-a41c-45450c070c06
sudo cryptsetup luksDump /dev/disk/by-uuid/0a995aba-d644-44fe-a86e-38ae467ccbfa
sudo systemd-cryptenroll --tpm2-device=list
```

Confirm UEFI boot, TPM2 availability, the actual firmware Secure Boot state,
and **LUKS2** on both volumes. `systemd-cryptenroll` TPM2 tokens require
LUKS2; stop rather than trying to convert either live volume blindly.

Verify that existing passphrases unlock both volumes. Create separate LUKS2
recovery keys and back up LUKS headers to a secure OFFLINE location (not this
repository, not the same disk). For each verified device, run:

```sh
sudo systemd-cryptenroll --recovery-key /dev/disk/by-uuid/<LUKS-UUID>
sudo cryptsetup luksHeaderBackup /dev/disk/by-uuid/<LUKS-UUID> --header-backup-file /path/to/OFFLINE-HEADER
```

Keep the original passphrase key slots, record and protect the recovery keys,
and verify that the backups and recovery procedure are usable. A LUKS header
backup is sensitive key material and must be stored securely.

## Stage 1 — enable signing, then firmware Secure Boot

Follow the pinned [Lanzaboote instructions](https://nix-community.github.io/lanzaboote/)
and the laptop firmware manual. Do this only with recovery-console access.

1. Create local signing keys: `sudo sbctl create-keys`. Back up
   `/var/lib/sbctl` securely outside the machine; never commit it to Git.
2. Evaluate and prepare the signed generation from this checkout:
   ```sh
   nix eval --no-update-lock-file --raw .#nixosConfigurations.meanovo-secure.config.system.build.toplevel.drvPath
   sudo nixos-rebuild boot --flake .#meanovo-secure
   sudo sbctl verify
   ```
   Building signed artifacts needs the local private signing keys.
3. Verify the signed EFI files, then follow the firmware-specific procedure
   to enter Setup Mode and enroll your signing keys with `sbctl`. Retain
   Microsoft/firmware keys when required for option ROMs or firmware updates.
   Do **not** clear keys blindly or enable automatic key enrollment.
4. Enable firmware Secure Boot and reboot with the local LUKS recovery
   passphrases ready. The first boot may still prompt for both passphrases,
   because no TPM tokens have been enrolled.
5. Confirm `bootctl status` reports Secure Boot **enabled** and validate
   signatures with `sudo sbctl verify`. Do not continue until you have
   recovered from at least one signed boot and can still unlock with passwords.

If firmware refuses to boot signed NixOS, restore the previously known-good
firmware trust configuration or disable Secure Boot through authorized
firmware controls, then boot a known-good generation/rescue system.

## Stage 2 — TPM2 enrollment (only after Secure Boot works)

Bind **both** volumes to PCR 7 *after* the final firmware signing policy is
in effect. This policy protects against changes to Secure Boot policy but
does not attest the complete kernel/initrd; a PIN or measured-boot policy
would be stronger. Keep the recovery and original passphrase slots.

```sh
sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 \
  /dev/disk/by-uuid/247a442b-20ea-42ef-a41c-45450c070c06
sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 \
  /dev/disk/by-uuid/0a995aba-d644-44fe-a86e-38ae467ccbfa
```

These are **manual**, stateful operations; check each device and its tokens
before enrollment. Do not remove any passphrase/recovery slot. On subsequent
Secure Boot DB/PK changes, PCR 7 can change: unlock with the saved passphrase
and re-enroll the TPM binding only after confirming recovery. If replacing an
existing TPM slot, explicitly review the `--wipe-slot=tpm2` option first.

After enrollment, reboot at least twice to verify unattended unlock of root
**and swap**, and test recovery-key fallback while you still have physical
console access. Watch the journal for systemd-cryptsetup errors.

TPM-only unlock without a PIN allows this machine to start automatically
when its approved Secure Boot policy is intact; it is not equivalent to a
second authentication factor. SDDM still requires an account password.

## Resolution changes / flicker-free boot

`profiles/workstation.nix` currently sets systemd-boot
`consoleMode = "max"`. `meanovo/configuration.nix` overrides it to
`"keep"`, preventing **systemd-boot itself** from selecting a new UEFI
console mode. The existing `quiet`/`splash` kernel parameters and
Plymouth are retained.

This **does not prove a flicker-free boot**: kernel DRM/KMS, Plymouth,
the SDDM greeter (Weston on the new workstation profile) and Niri may
each select a display mode. A change of resolution or refresh rate at a
handoff may still cause a black flash; complete elimination depends on
the laptop's EFI GOP and graphics driver modes. Do not force an `i915`
or `xe` early-KMS driver without confirming the actual graphics device.

After the SDDM rollout, record the kernel graphics driver (`lspci -nnk`),
firmware console mode (`bootctl status`) and supported DRM modes in
`/sys/class/drm/`, then observe the boot stages to identify any remaining
mode change. Prefer matching the firmware mode, greeter mode and Niri
output mode rather than forcing a resolution without hardware evidence.

## Boot menu retention

Both `meanovo` (systemd-boot) and `meanovo-secure` (Lanzaboote) retain
at most **four** NixOS generations in the boot menu. Lanzaboote inherits
`boot.loader.systemd-boot.configurationLimit`. The limit is applied at
the next **successful** bootloader installation, not by evaluating the flake.
This does not delete NixOS generations or store paths from disk.

Do not apply this retention reduction while the signed bootloader is in a
failed or partially installed state. First create and back up the local sbctl
signing keys, verify an intact known-good boot path and an external rescue
option, and complete a successful bootloader installation. Confirm the remaining
entries with `sudo bootctl list` before rebooting; do not depend solely on
one of the old generations that the limit may remove.

## Recovery and validation

Before activating this variant:

```sh
nix eval --no-update-lock-file --raw .#nixosConfigurations.meanovo.config.system.build.toplevel.drvPath
nix eval --no-update-lock-file --raw .#nixosConfigurations.meanovo-secure.config.system.build.toplevel.drvPath
```

The repository's automated CI checks syntax only. Successful evaluation or
signing does not prove the firmware accepts the keys, the TPM policy unlocks
either volume, or the display keeps a constant video mode. Always use
`nixos-rebuild boot` and a deliberate reboot for the first cutover, not
a live session switch. Retain a known-good boot generation and a trusted
non-destructive rescue USB.
