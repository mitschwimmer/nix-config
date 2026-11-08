# Invoked by writeShellApplication. Destructive only after read-only preflight.
test -d /sys/firmware/efi || { echo "UEFI boot is required." >&2; exit 1; }
test -s "$MEAWHITE_RECOVERY_FILE"
test -s "$MEAWHITE_AUTHORIZED_KEYS"
test -x "$MEAWHITE_DISKO_SCRIPT"
test -x "$MEAWHITE_SYSTEM/bin/switch-to-configuration"
check-meawhite-disks

echo "ERASING the three allowlisted meawhite disks."
install -m 0600 "$MEAWHITE_RECOVERY_FILE" /run/meawhite-recovery-passphrase
trap 'rm -f /run/meawhite-recovery-passphrase' EXIT
DISKO_SKIP_SWAP=1 "$MEAWHITE_DISKO_SCRIPT"
nixos-install --root /mnt --system "$MEAWHITE_SYSTEM" \
  --no-channel-copy --no-root-password --option substituters "" --option builders ""
install -Dm0644 "$MEAWHITE_AUTHORIZED_KEYS" /mnt/etc/ssh/authorized_keys.d/root

# Both volumes retain their recovery passphrase slot, even if TPM enrollment fails.
for device in /dev/disk/by-partlabel/disk-main-root /dev/md/meawhite-data; do
  if systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 \
      --unlock-key-file=/run/meawhite-recovery-passphrase "$device"; then
    echo "TPM enrolled for $device against the current PCR 7 policy."
  else
    echo "TPM enrollment failed for $device; use the recovery passphrase." >&2
  fi
done

sync
umount -R /mnt
cryptsetup close cryptdata
cryptsetup close cryptroot
mdadm --stop /dev/md/meawhite-data
echo "Installation complete. REMOVE THE USB before powering on again."
