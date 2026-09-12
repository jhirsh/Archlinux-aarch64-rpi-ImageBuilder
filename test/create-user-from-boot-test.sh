#!/bin/bash

# One check for create-user-from-boot: that name:password becomes a wheel
# user with sudo and the card's keys, and that the file does not survive.
#
# useradd, chpasswd, id, getent and chown are stubbed, so nothing here
# touches a real account.

set -euo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
script="$here/../src/usr/local/bin/create-user-from-boot"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/home"
cat >"$tmp/bin/useradd" <<STUB
#!/bin/bash
echo "\$*" >>"$tmp/useradd.log"
STUB
cat >"$tmp/bin/chpasswd" <<STUB
#!/bin/bash
cat >>"$tmp/chpasswd.in"
STUB
cat >"$tmp/bin/id" <<STUB
#!/bin/bash
exit 1
STUB
cat >"$tmp/bin/getent" <<STUB
#!/bin/bash
echo "\$2:x:1000:1000::$tmp/home:/bin/bash"
STUB
for s in chown sync; do printf '#!/bin/bash\nexit 0\n' >"$tmp/bin/$s"; done
chmod +x "$tmp/bin"/*
export PATH="$tmp/bin:$PATH"

fail() { printf 'not ok - %s\n%s\n' "$1" "${2:-}" >&2; exit 1; }
pass() { printf 'ok - %s\n' "$1"; }

run() {
  rm -rf "$tmp/boot" "$tmp/home/.ssh" "$tmp/useradd.log" "$tmp/chpasswd.in" "$tmp/sudoers"
  mkdir -p "$tmp/boot"
  [[ $# -gt 0 ]] && printf '%s' "$1" >"$tmp/boot/userconf"
  [[ ${2:-} ]] && printf '%s\n' "$2" >"$tmp/boot/authorized_keys"
  USERCONF_FILE="$tmp/boot/userconf" AUTHORIZED_KEYS_SOURCE="$tmp/boot/authorized_keys" \
  SUDOERS_FILE="$tmp/sudoers" bash "$script" >/dev/null
}

run $'jonas:pa:ss word\r\n' 'ssh-ed25519 AAAAmine me@laptop'
grep -q -- '--groups wheel' "$tmp/useradd.log" || fail "the user is created in wheel" "$(cat "$tmp/useradd.log" 2>&1)"
[[ $(cat "$tmp/chpasswd.in") == "jonas:pa:ss word" ]] || fail "the password is everything after the first colon" "$(cat "$tmp/chpasswd.in")"
grep -qx '%wheel ALL=(ALL:ALL) ALL' "$tmp/sudoers" || fail "wheel gets sudo" "$(cat "$tmp/sudoers" 2>&1)"
[[ $(cat "$tmp/home/.ssh/authorized_keys") == "ssh-ed25519 AAAAmine me@laptop" ]] ||
  fail "the card's keys are installed for the user" "$(cat "$tmp/home/.ssh/authorized_keys" 2>&1)"
[[ ! -e "$tmp/boot/userconf" ]] || fail "userconf is deleted after it is used"
pass "name:password becomes a wheel user with sudo and the card's keys; the file is deleted"

run $'jonas\n'
[[ ! -e "$tmp/useradd.log" && ! -e "$tmp/chpasswd.in" ]] || fail "a line without a colon creates nothing"
[[ ! -e "$tmp/boot/userconf" ]] || fail "a bad file is still cleaned up"
pass "a line without a password creates nothing and is cleaned up"

run
[[ ! -e "$tmp/useradd.log" ]] || fail "no file means no user"
pass "no file at all means no user, and no error"
