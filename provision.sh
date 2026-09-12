#!/bin/bash

# Provision a freshly flashed card from the machine that flashed it.
#
# The image carries no credentials, so a card needs yours before its first
# boot: an SSH key, and WiFi if there is no Ethernet cable. This writes them
# to the boot partition, which is FAT32 and mounts as an ordinary volume the
# moment the card is written. The Pi reads each file on its first boot and
# deletes the ones that held a secret.
#
#     ./provision.sh -w 'Home Net'
#
# Then boot the Pi and: ssh root@archlinux-<sha>-rpi5.local

set -euo pipefail
shopt -s nullglob

usage() {
  cat >&2 <<USAGE
usage: $0 [-k PUBKEY] [-w SSID] [-p] [VOLUME]

  -k PUBKEY   public key that may log in as root (default: the only ~/.ssh/*.pub)
  -w SSID     WiFi network to join on first boot; the passphrase is prompted for
  -p          also set a root password for the console; prompted for
  VOLUME      the card's boot partition (default: /Volumes/RPI64-BOOT)
USAGE
  exit 2
}

pubkey="" ssid="" want_rootpw=""
while getopts 'k:w:ph' opt; do
  case $opt in
    k) pubkey=$OPTARG ;;
    w) ssid=$OPTARG ;;
    p) want_rootpw=1 ;;
    *) usage ;;
  esac
done
shift $((OPTIND - 1))
volume="${1:-/Volumes/RPI64-BOOT}"

[[ -f $volume/config.txt ]] || { echo "$volume is not a mounted boot partition" >&2; exit 1; }

if [[ -z $pubkey ]]; then
  keys=(~/.ssh/*.pub)
  [[ ${#keys[@]} -eq 1 ]] || { echo "found ${#keys[@]} public keys in ~/.ssh; say which with -k" >&2; exit 1; }
  pubkey=${keys[0]}
fi
[[ -f $pubkey ]] || { echo "no such key: $pubkey" >&2; exit 1; }

cp "$pubkey" "$volume/authorized_keys"
echo "authorized_keys  <- $pubkey"

if [[ -n $ssid ]]; then
  IFS= read -rsp "passphrase for '$ssid': " pass; echo
  printf '%s\n%s\n' "$ssid" "$pass" >"$volume/wifi"
  echo "wifi             <- '$ssid' (deleted by the Pi on first boot)"
fi

if [[ -n $want_rootpw ]]; then
  IFS= read -rsp 'root password: ' pw; echo
  printf '%s\n' "$pw" >"$volume/rootpw"
  echo "rootpw           <- (deleted by the Pi on first boot)"
fi

sync
if command -v diskutil >/dev/null; then
  diskutil eject "$volume"
else
  echo "now unmount $volume and boot the Pi"
fi
