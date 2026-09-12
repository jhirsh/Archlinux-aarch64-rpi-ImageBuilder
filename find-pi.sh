#!/bin/bash

# Find a freshly booted Raspberry Pi on this network, for the first ssh.
#
# The Pi answers to <hostname>.local over mDNS, and that is the name to use.
# When it does not resolve (a router that drops multicast, a guest network,
# a laptop that is sure it knows better) the Pi is still one ping away: its
# DHCP address changes between boots, but its MAC address does not, and the
# first three bytes of every Pi's MAC belong to Raspberry Pi. So ping the
# whole subnet to fill the ARP cache, then read the Pi out of it.
#
#     ./find-pi.sh
#     ssh root@<the address it prints>
#
# This is for the first boot or two. Once in, give the Pi a name that outlives
# its address: a DHCP reservation on the router, or `tailscale up`.

set -uo pipefail

# Raspberry Pi's OUIs. macOS prints MAC octets without leading zeros.
ouis='b8:27:eb|dc:a6:32|e4:5f:0?1|d8:3a:dd|2c:cf:67|28:cd:c1|88:a2:9e'

# stdin: lines from arp -an or ip neigh. stdout: the IPv4 of every Pi in them.
pis() {
  grep -iE "($ouis):" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}'
}

# Sourced by the test for pis(); everything below runs only as a command.
[[ ${BASH_SOURCE[0]} == "$0" ]] || return 0

if command -v ipconfig >/dev/null; then
  me=$(ipconfig getifaddr "$(route -n get default | awk '/interface:/{print $2}')")
else
  me=$(hostname -I | awk '{print $1}')
fi
[[ -n ${me:-} ]] || { echo "cannot tell my own address; am I on a network?" >&2; exit 1; }

# ponytail: assumes a /24, which is what every home router hands out.
# -t1 is a one second timeout on macOS and TTL 1 on Linux; both work on the
# local segment, Linux just waits its default ten seconds for the silent ones.
for i in $(seq 1 254); do ping -c1 -t1 "${me%.*}.$i" >/dev/null 2>&1 & done
wait

found=$({ arp -an 2>/dev/null || ip -4 neigh; } | pis | sort -u)
[[ -n $found ]] || { echo "no Raspberry Pi answered on ${me%.*}.0/24" >&2; exit 1; }
for ip in $found; do echo "ssh root@$ip"; done
