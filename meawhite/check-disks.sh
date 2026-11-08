# Read-only preflight; invoked by writeShellApplication with strict options.
udevadm settle
iso_device=$(findmnt --noheadings --raw --output SOURCE /iso)
test -b "$iso_device" || { echo "Cannot identify installer medium." >&2; exit 1; }
ancestors=$(lsblk --inverse --noheadings --raw --paths --output NAME "$iso_device")
test -n "$ancestors" || { echo "Cannot identify installer ancestors." >&2; exit 1; }

declare -A seen=()
for id in nvme-eui.002538a4514017bc wwn-0x5000c5009dcaa25a wwn-0x5000c5009dccc120; do
  disk=$(readlink -e "/dev/disk/by-id/$id")
  test -b "$disk" || { echo "Missing target disk: $id" >&2; exit 1; }
  if [[ -n ${seen[$disk]:-} ]]; then
    echo "Duplicate target disk: $disk" >&2; exit 1
  fi
  seen[$disk]=1
  if grep -Fxq "$disk" <<< "$ancestors"; then
    echo "Target contains installer: $disk" >&2; exit 1
  fi
  inventory=$(lsblk --json --paths --output NAME,TYPE,TRAN,RM,RO,MOUNTPOINTS "$disk")
  if ! jq -e '
    .blockdevices | length == 1 and (.[0] |
      .type == "disk" and (.ro | not) and (.rm | not) and .tran != "usb" and
      all(recurse(.children[]?); all(.mountpoints[]?; . == null or . == "")))
  ' <<< "$inventory" >/dev/null; then
    echo "Target must be an unmounted writable internal disk: $disk" >&2; exit 1
  fi
  devices=$(lsblk --noheadings --raw --paths --output NAME "$disk")
  test -n "$devices" || { echo "Cannot inspect target: $disk" >&2; exit 1; }
  while IFS= read -r device; do
    for holder in /sys/class/block/"${device##*/}"/holders/*; do
      if test -e "$holder"; then
        echo "Target has an active mapping: $device" >&2; exit 1
      fi
    done
  done <<< "$devices"
  echo "Validated target: $disk" >&2
done
