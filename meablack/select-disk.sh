# Read-only disk discovery. Print only the selected whole-disk path on stdout.
udevadm settle
disks=$(lsblk --json --bytes --paths --nodeps --output NAME,TYPE,TRAN,RM,RO)
if ! disk=$(jq -er '
  [.blockdevices[]
   | select(.type == "disk" and .rm == false and .ro == false and .tran != "usb")]
  | if length == 1 then .[0].name
    else error("Expected exactly one internal writable disk; found \(length).")
    end
' <<< "$disks"); then
  lsblk -o NAME,SIZE,MODEL,SERIAL,TRAN,RM,RO >&2
  exit 1
fi

# Exclude the live ISO's physical ancestors even if its adapter misreports USB.
iso_device=$(findmnt --noheadings --raw --output SOURCE /iso)
test -b "$iso_device" || { echo "Cannot identify the installer medium." >&2; exit 1; }
ancestors=$(lsblk --inverse --noheadings --raw --paths --output NAME "$iso_device")
if grep -Fxq "$disk" <<< "$ancestors"; then
  echo "The selected disk contains the installer; refusing to erase it." >&2
  exit 1
fi
printf '%s\n' "$disk"
