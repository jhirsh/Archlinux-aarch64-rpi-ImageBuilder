#!/bin/bash

# One check for join-wifi-from-boot: that a two-line file becomes the iwd
# network iwd will actually read, and that the file does not survive.

set -euo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
script="$here/../src/usr/local/bin/join-wifi-from-boot"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
printf '#!/bin/bash\nexit 0\n' >"$tmp/sync"; chmod +x "$tmp/sync"; export PATH="$tmp:$PATH"

fail() { printf 'not ok - %s\n%s\n' "$1" "${2:-}" >&2; exit 1; }
pass() { printf 'ok - %s\n' "$1"; }

run() {
  rm -rf "$tmp/boot" "$tmp/iwd"; mkdir -p "$tmp/boot"
  [[ $# -gt 0 ]] && printf '%s' "$1" >"$tmp/boot/wifi"
  WIFI_FILE="$tmp/boot/wifi" IWD_DIR="$tmp/iwd" bash "$script" >/dev/null
}

run $'Home Net\ncorrect horse $battery staple\n'
[[ -f "$tmp/iwd/Home Net.psk" ]] || fail "a plain SSID names the file" "$(ls "$tmp/iwd" 2>&1)"
grep -qxF 'Passphrase=correct horse $battery staple' "$tmp/iwd/Home Net.psk" ||
  fail "the passphrase is written as typed" "$(cat "$tmp/iwd/Home Net.psk")"
[[ $(stat -f '%Lp' "$tmp/iwd/Home Net.psk" 2>/dev/null || stat -c '%a' "$tmp/iwd/Home Net.psk") == "600" ]] ||
  fail "the network file is not readable by anyone else"
[[ ! -e "$tmp/boot/wifi" ]] || fail "the wifi file is deleted after it is used"
pass "a plain SSID becomes <ssid>.psk, mode 600, and the file is deleted"

run $'Caf\xc3\xa9!\npw\n'
[[ -f "$tmp/iwd/=436166c3a921.psk" ]] || fail "an SSID with odd characters is hex-named" "$(ls "$tmp/iwd" 2>&1)"
pass "an SSID iwd cannot name plainly is written as =<hex>.psk"

run $'Home Net\r\npw\r\n'
grep -qxF 'Passphrase=pw' "$tmp/iwd/Home Net.psk" || fail "CRLF line endings are stripped" "$(cat "$tmp/iwd/Home Net.psk")"
pass "a file written on Windows still works"

run $'Home Net\n'
[[ ! -e "$tmp/iwd" || -z $(ls -A "$tmp/iwd") ]] || fail "a missing passphrase writes nothing"
[[ ! -e "$tmp/boot/wifi" ]] || fail "a bad file is still cleaned up"
pass "a file without a passphrase joins nothing and is cleaned up"

run
[[ ! -e "$tmp/iwd" ]] || fail "no file means nothing is written"
pass "no file at all means no WiFi, and no error"
