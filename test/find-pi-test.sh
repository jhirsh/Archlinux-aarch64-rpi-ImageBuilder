#!/bin/bash

# One check for find-pi.sh: that it picks Raspberry Pi addresses out of an ARP
# table, in both the macOS shape (leading zeros dropped) and the Linux one.

set -euo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$here/../find-pi.sh"

fail() { printf 'not ok - %s\n%s\n' "$1" "${2:-}" >&2; exit 1; }
pass() { printf 'ok - %s\n' "$1"; }

got=$(pis <<'ARP'
? (192.168.1.1) at 0:11:22:33:44:55 on en0 ifscope [ethernet]
? (192.168.1.23) at d8:3a:dd:1:2:3 on en0 ifscope [ethernet]
? (192.168.1.50) at e4:5f:1:aa:bb:cc on en0 ifscope [ethernet]
? (192.168.1.99) at (incomplete) on en0 ifscope [ethernet]
192.168.1.40 dev wlan0 lladdr dc:a6:32:aa:bb:cc REACHABLE
192.168.1.41 dev wlan0 lladdr 3c:22:fb:aa:bb:cc REACHABLE
ARP
)
[[ $got == $'192.168.1.23\n192.168.1.50\n192.168.1.40' ]] ||
  fail "only the Pi addresses come out, from macOS and Linux lines alike" "$got"
pass "Pi addresses are picked out of macOS and Linux ARP tables"
