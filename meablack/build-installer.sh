#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

key_file=${MEABLACK_RECOVERY_PASSPHRASE_FILE:-}
if [[ -z "$key_file" || "$key_file" != /* ]]; then
  echo "Set MEABLACK_RECOVERY_PASSPHRASE_FILE to an absolute path outside this checkout." >&2
  exit 1
fi
case "$key_file" in
  "$PWD"/*) echo "Keep the recovery passphrase outside the Git checkout." >&2; exit 1 ;;
esac
if [[ ! -e "$key_file" ]]; then
  umask 077
  # Hex is easy to type at an initrd prompt and provides 256 bits of entropy.
  openssl rand -hex 32 | tr -d '\n' > "$key_file"
fi
if ! [[ $(cat "$key_file") =~ ^[0-9a-f]{64}$ ]] || [[ $(wc -c < "$key_file") -ne 64 ]]; then
  echo "Expected a file containing exactly 64 lowercase hex characters, without newline." >&2
  exit 1
fi
ssh-keygen -lf meablack/authorized_keys
export MEABLACK_RECOVERY_PASSPHRASE_FILE="$key_file"
nix build --impure --no-update-lock-file .#meablack-installer "$@"
echo "ISO: result/iso/meablack-unattended.iso"
echo "Recovery passphrase: $key_file (also included on the ISO). Keep both private."
