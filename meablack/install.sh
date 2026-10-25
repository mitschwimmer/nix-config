# Invoked by writeShellApplication with strict shell options and a pinned PATH.
# This script is deliberately destructive and has no confirmation prompt.
test -d /sys/firmware/efi || { echo "UEFI boot is required." >&2; exit 1; }
test -s "$MEABLACK_RECOVERY_FILE"
test -x "$MEABLACK_DISKO_SCRIPT"
test -x "$MEABLACK_SYSTEM/bin/switch-to-configuration"
disk=$(select-meablack-disk)

echo "ERASING $disk and installing meablack."
lsblk -o NAME,SIZE,MODEL,SERIAL,TRAN "$disk"
install -m 0600 "$MEABLACK_RECOVERY_FILE" /run/meablack-recovery-passphrase
trap 'rm -f /run/meablack-recovery-passphrase' EXIT
mkdir -p /dev/disk/by-id
ln -sfn "$disk" /dev/disk/by-id/meablack-install-target
DISKO_SKIP_SWAP=1 "$MEABLACK_DISKO_SCRIPT"

# Install the already-built closure; never evaluate or build a flake here.
nixos-install --root /mnt --system "$MEABLACK_SYSTEM" \
  --no-channel-copy --no-root-password --option substituters "" --option builders ""
# Activation installs declarative /etc files at first boot; seed keys now too.
install -Dm0644 "$MEABLACK_AUTHORIZED_KEYS" /mnt/etc/ssh/authorized_keys.d/root

luks_device=/dev/disk/by-partlabel/disk-main-root
# The passphrase slot is always retained. TPM enrollment is opportunistic:
# without a usable TPM the disk still boots with the passphrase from the USB.
if systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 \
    --unlock-key-file=/run/meablack-recovery-passphrase "$luks_device"; then
  echo "TPM enrolled against the current PCR 7 policy."
else
  echo "TPM enrollment unavailable. Enter the USB recovery passphrase at disk boot." >&2
fi

sync
umount -R /mnt
cryptsetup close cryptroot
echo "Installation complete. Powering off; REMOVE THE USB before powering on."
