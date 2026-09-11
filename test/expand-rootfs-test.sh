#!/bin/bash

# One check for expand-rootfs, covering the only part of it with any logic:
# working out which disk and which partition number root is on, across the
# three device naming schemes a Pi can boot from.
#
# Every command that would touch a disk is stubbed, so this runs anywhere.

set -euo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
script="$here/../src/usr/local/bin/expand-rootfs"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/bin"

for command in sfdisk partx resize2fs df; do
  printf '#!/bin/bash\nprintf "%s %%s\\n" "$*" >>"$CALLS"\n' "$command" >"$tmp/bin/$command"
done

cat >"$tmp/bin/findmnt" <<'STUB'
#!/bin/bash
case "$*" in
  *FSTYPE*) echo "${STUB_FSTYPE:-ext4}" ;;
  *) echo "$STUB_ROOT_SOURCE" ;;
esac
STUB

cat >"$tmp/bin/lsblk" <<'STUB'
#!/bin/bash
echo "$STUB_PARENT"
STUB

chmod +x "$tmp/bin"/*
export PATH="$tmp/bin:$PATH"
export CALLS="$tmp/calls"

fail() { printf 'not ok - %s\n%s\n' "$1" "${2:-}" >&2; exit 1; }
pass() { printf 'ok - %s\n' "$1"; }

expand() {
  : >"$CALLS"
  rm -f "$tmp/marker"
  STUB_ROOT_SOURCE="$1" STUB_PARENT="$2" STUB_FSTYPE="${3:-ext4}" \
  EXPAND_ROOTFS_MARKER="$tmp/marker" \
    bash "$script" >/dev/null
}

# An SD card, an NVMe drive and a USB disk name their partitions differently,
# and the "p" only separates when the disk name ends in a digit. Getting this
# wrong means sfdisk is pointed at the wrong partition.
for case in "mmcblk0p2 mmcblk0 2" "nvme0n1p2 nvme0n1 2" "sda2 sda 2"; do
  set -- $case
  expand "/dev/$1" "$2"
  grep -qF -- "sfdisk --force --no-reread --no-tell-kernel -N $3 /dev/$2" "$CALLS" ||
    fail "$1 is read as partition $3 of $2" "$(cat "$CALLS")"
  grep -qF -- "partx --update --nr $3 /dev/$2" "$CALLS" ||
    fail "$1 tells the kernel about partition $3" "$(cat "$CALLS")"
  grep -qF -- "resize2fs /dev/$1" "$CALLS" ||
    fail "$1 has its filesystem resized" "$(cat "$CALLS")"
done
pass "the disk and partition number are read from every device naming scheme"

[[ -f $tmp/marker ]] || fail "a successful run leaves the marker the unit checks"
pass "a successful run leaves the marker the unit checks"

# Resizing something that is not ext4 with resize2fs would corrupt it.
expand /dev/mmcblk0p2 mmcblk0 btrfs
[[ ! -s $CALLS ]] || fail "a non-ext4 root is left completely alone" "$(cat "$CALLS")"
pass "a non-ext4 root is left completely alone"

# A partition with no parent disk, which is what a loop or mapper device looks
# like here, has nothing to grow into.
expand /dev/mmcblk0p2 ""
[[ ! -s $CALLS ]] || fail "a device with no parent disk is left alone" "$(cat "$CALLS")"
pass "a device with no parent disk is left alone"
