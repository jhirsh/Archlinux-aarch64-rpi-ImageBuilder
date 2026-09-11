#!/bin/bash

# One check for set-root-password-from-boot: that it reads the password the
# way a person actually writes the file, and that the file does not survive.
#
# chpasswd is stubbed, so nothing here touches a real account.

set -euo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
script="$here/../src/usr/local/bin/set-root-password-from-boot"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/bin"
cat >"$tmp/bin/chpasswd" <<'STUB'
#!/bin/bash
cat >>"$CHPASSWD_INPUT"
STUB
printf '#!/bin/bash\nexit 0\n' >"$tmp/bin/sync"
chmod +x "$tmp/bin"/*
export PATH="$tmp/bin:$PATH"
export CHPASSWD_INPUT="$tmp/chpasswd.in"

fail() { printf 'not ok - %s\n%s\n' "$1" "${2:-}" >&2; exit 1; }
pass() { printf 'ok - %s\n' "$1"; }

run() {
  : >"$CHPASSWD_INPUT"
  if [[ $# -gt 0 ]]; then
    printf '%b' "$1" >"$tmp/rootpw"
  else
    rm -f "$tmp/rootpw"
  fi
  ROOTPW_FILE="$tmp/rootpw" bash "$script" >/dev/null
}

# `echo 'pw' > rootpw` leaves a trailing newline, and a file written on
# Windows leaves \r\n. Neither is part of the password, and carrying either
# into chpasswd sets a password nobody can type.
run 'hunter2\n'
[[ $(cat "$CHPASSWD_INPUT") == "root:hunter2" ]] ||
  fail "a trailing newline is not part of the password" "$(cat "$CHPASSWD_INPUT")"

run 'hunter2\r\n'
[[ $(cat "$CHPASSWD_INPUT") == "root:hunter2" ]] ||
  fail "a CRLF line ending is not part of the password" "$(cat "$CHPASSWD_INPUT")"

run 'hunter2\nignored second line\n'
[[ $(cat "$CHPASSWD_INPUT") == "root:hunter2" ]] ||
  fail "only the first line is read" "$(cat "$CHPASSWD_INPUT")"
pass "the password is read as written, without line endings"

# A password with spaces and symbols has to survive intact, or someone locks
# themselves out of the console with a password they typed correctly.
run 'a b$c"d ef\n'
[[ $(cat "$CHPASSWD_INPUT") == 'root:a b$c"d ef' ]] ||
  fail "spaces and symbols survive" "$(cat "$CHPASSWD_INPUT")"
pass "spaces and shell metacharacters survive intact"

# The whole point of the file is that it stops existing.
run 'hunter2\n'
[[ ! -e $tmp/rootpw ]] || fail "the password file is deleted after it is used"
pass "the password file is deleted after it is used"

# An empty file is a mistake, not an instruction to set an empty password --
# which would be far worse than leaving the account locked.
run '\n'
[[ ! -s $CHPASSWD_INPUT ]] || fail "an empty file sets no password" "$(cat "$CHPASSWD_INPUT")"
[[ ! -e $tmp/rootpw ]] || fail "an empty file is still cleaned up"
pass "an empty file sets no password and is cleaned up"

run
[[ ! -s $CHPASSWD_INPUT ]] || fail "no file means no password is set" "$(cat "$CHPASSWD_INPUT")"
pass "no file at all means root stays locked"
