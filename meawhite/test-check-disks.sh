#!/usr/bin/env bash
# Only command mocks and synthetic devices; no real disk access.
set -euo pipefail
cd "$(dirname "$0")"

udevadm() { :; }
findmnt() {
  [[ $scenario != unknown-iso ]] || return 1
  echo /dev/test-iso
}
readlink() {
  case ${*: -1} in
    *nvme-eui*) echo /dev/test-root ;;
    *9dcaa25a) echo /dev/test-data1 ;;
    *9dccc120)
      [[ $scenario != missing ]] || return 1
      if [[ $scenario == duplicate ]]; then echo /dev/test-data1; else echo /dev/test-data2; fi ;;
    *) return 1 ;;
  esac
}
test() {
  case $1 in
    -b) [[ $2 == /dev/test-* && $scenario != non-block ]] ;;
    -e) [[ $scenario == active && $2 == /sys/class/block/test-root/holders/* ]] ;;
    *) builtin test "$@" ;;
  esac
}
lsblk() {
  if [[ $1 == --inverse ]]; then
    [[ $scenario != no-ancestors ]] || return 0
    echo /dev/test-iso
    if [[ $scenario == installer-target ]]; then echo /dev/test-root; fi
  elif [[ $1 == --json ]]; then
    local type=disk ro=false rm=false tran=sata mount=null children='[]'
    case $scenario in
      partition) type=part ;;
      readonly) ro=true ;;
      removable) rm=true ;;
      usb) tran=usb ;;
      mounted) mount='"/mnt"' ;;
      mounted-child) children='[{"name":"/dev/test-root1","mountpoints":["/iso"]}]' ;;
      swap) children='[{"name":"/dev/test-root1","mountpoints":["[SWAP]"]}]' ;;
      empty-inventory) echo '{"blockdevices":[]}'; return ;;
    esac
    printf '{"blockdevices":[{"type":"%s","ro":%s,"rm":%s,"tran":"%s","mountpoints":[%s],"children":%s}]}\n' \
      "$type" "$ro" "$rm" "$tran" "$mount" "$children"
  else
    echo "${*: -1}"
  fi
}

export -f udevadm findmnt readlink test lsblk
for scenario in valid missing duplicate non-block unknown-iso no-ancestors installer-target \
    partition readonly removable usb mounted mounted-child swap active empty-inventory; do
  export scenario
  set +e
  bash -euo pipefail ./check-disks.sh > /dev/null 2>&1
  result=$?
  set -e
  if [[ $scenario == valid && $result != 0 ]] || [[ $scenario != valid && $result == 0 ]]; then
    echo "FAIL: $scenario" >&2; exit 1
  fi
  echo "PASS: $scenario"
done
