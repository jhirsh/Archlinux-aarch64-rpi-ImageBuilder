#!/bin/bash

# One check for provision.sh: that what it writes is what the first-boot
# scripts read, with the secrets taken from a prompt rather than an argument.

set -euo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/home/.ssh" "$tmp/vol" "$tmp/bin"
printf 'ssh-ed25519 AAAAtest me@laptop\n' >"$tmp/home/.ssh/laptop_ed25519.pub"
: >"$tmp/vol/config.txt"
printf '#!/bin/bash\nexit 0\n' >"$tmp/bin/diskutil"; printf '#!/bin/bash\nexit 0\n' >"$tmp/bin/sync"
chmod +x "$tmp/bin"/*
export PATH="$tmp/bin:$PATH" HOME="$tmp/home"

fail() { printf 'not ok - %s\n%s\n' "$1" "${2:-}" >&2; exit 1; }
pass() { printf 'ok - %s\n' "$1"; }

printf 'wifi pass word\nuser pass word\nroot pass word\n' | bash "$here/../provision.sh" -w 'Home Net' -u jonas -p "$tmp/vol" >/dev/null ||
  fail "provision.sh exits cleanly"
[[ $(cat "$tmp/vol/authorized_keys") == "ssh-ed25519 AAAAtest me@laptop" ]] ||
  fail "the only key in ~/.ssh is used without -k" "$(cat "$tmp/vol/authorized_keys" 2>&1)"
[[ $(cat "$tmp/vol/wifi") == $'Home Net\nwifi pass word' ]] || fail "wifi is SSID then passphrase" "$(cat "$tmp/vol/wifi")"
[[ $(cat "$tmp/vol/userconf") == "jonas:user pass word" ]] || fail "userconf is name:password" "$(cat "$tmp/vol/userconf")"
[[ $(cat "$tmp/vol/rootpw") == "root pass word" ]] || fail "rootpw is the one prompted line" "$(cat "$tmp/vol/rootpw")"
pass "key, wifi, userconf and rootpw land on the card in the shape the Pi reads"

bash "$here/../provision.sh" "$tmp/nope" 2>/dev/null && fail "a non-boot volume is refused"
pass "a directory without config.txt is refused"
