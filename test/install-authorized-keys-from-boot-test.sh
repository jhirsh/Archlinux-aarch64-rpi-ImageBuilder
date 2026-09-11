#!/bin/bash

# One check for install-authorized-keys-from-boot: that it seeds when there is
# nothing there, and never clobbers keys the machine already has.

set -euo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
script="$here/../src/usr/local/bin/install-authorized-keys-from-boot"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fail() { printf 'not ok - %s\n%s\n' "$1" "${2:-}" >&2; exit 1; }
pass() { printf 'ok - %s\n' "$1"; }

seed() {
  rm -rf "$tmp/boot" "$tmp/home"
  mkdir -p "$tmp/boot" "$tmp/home/.ssh"
  [[ -n ${1:-} ]] && printf '%s\n' "$1" >"$tmp/boot/authorized_keys"
  [[ -n ${2:-} ]] && printf '%s\n' "$2" >"$tmp/home/.ssh/authorized_keys"
  AUTHORIZED_KEYS_SOURCE="$tmp/boot/authorized_keys" \
  AUTHORIZED_KEYS_TARGET="$tmp/home/.ssh/authorized_keys" \
    bash "$script" >/dev/null
}

# The published image ships with no keys at all, so this is the only way in.
seed "ssh-ed25519 AAAAmine me@laptop"
[[ $(cat "$tmp/home/.ssh/authorized_keys") == "ssh-ed25519 AAAAmine me@laptop" ]] ||
  fail "a key on the boot partition is installed" "$(cat "$tmp/home/.ssh/authorized_keys" 2>&1)"
[[ $(stat -f '%Lp' "$tmp/home/.ssh/authorized_keys" 2>/dev/null || stat -c '%a' "$tmp/home/.ssh/authorized_keys") == "600" ]] ||
  fail "the installed file is not readable by anyone else"
pass "a key on the boot partition is installed, mode 600"

# ssh-copy-id after the fact must survive a reboot.
seed "ssh-ed25519 AAAAfromboot boot@card" "ssh-ed25519 AAAAexisting already@there"
[[ $(cat "$tmp/home/.ssh/authorized_keys") == "ssh-ed25519 AAAAexisting already@there" ]] ||
  fail "existing keys are never overwritten" "$(cat "$tmp/home/.ssh/authorized_keys")"
pass "keys already on the machine are never overwritten"

# No file is the state a freshly built image is in, and it must not error.
seed
[[ ! -s $tmp/home/.ssh/authorized_keys ]] || fail "no source means no keys" "$(cat "$tmp/home/.ssh/authorized_keys")"
pass "no file on the boot partition leaves root with no keys"

# An empty file is a mistake, not a reason to create an empty authorized_keys.
seed ""
[[ ! -s $tmp/home/.ssh/authorized_keys ]] || fail "an empty source installs nothing"
pass "an empty file on the boot partition installs nothing"

# The file was written on Windows more often than not, and Notepad ends every
# line with CRLF.
seed $'ssh-ed25519 AAAAwindows me@pc\r'
[[ $(cat "$tmp/home/.ssh/authorized_keys") == "ssh-ed25519 AAAAwindows me@pc" ]] ||
  fail "CR line endings are stripped" "$(od -c "$tmp/home/.ssh/authorized_keys")"
pass "a file with Windows line endings installs clean keys"
