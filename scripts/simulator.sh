#!/bin/sh
# Prints the UDID of the iPhone simulator this checkout tests on, creating it on first use.
#
# Two `xcodebuild test` runs installing app.opendiving.ios on the same device kill each
# other's test host, and worktrees of this repository run their tests concurrently on one
# Mac, so no two checkouts may get the same device.
#
# Where `ontherun-lease.sh` is on PATH the device is a slot of a pool of four, leased to
# this checkout: the number of simulators stays at four however many worktrees come and
# go, and a fifth concurrent checkout waits for a slot instead of sharing one. Anywhere
# else - CI, a plain terminal - it is a simulator named after the checkout's path.
set -eu

pool=opendiving-sim
pool_size=4

root=$(cd "$(dirname "$0")/.." && pwd -P)
slot=
fresh_slot=

if command -v ontherun-lease.sh >/dev/null 2>&1; then
  # A lease file still naming this checkout means nobody else has had the slot since.
  held=$(ontherun-lease.sh list "$pool" |
    owner=$root awk -F '\t' '$5 == ENVIRON["owner"] { print $2; exit }')
  if ! slot=$(ontherun-lease.sh acquire "$pool" "$pool_size" --owner "$root" --wait 1800); then
    echo "simulator.sh: no simulator slot to lease in pool $pool" >&2
    exit 1
  fi
  case $slot in
    '' | *[!0-9]*)
      echo "simulator.sh: ontherun-lease.sh printed no slot number: $slot" >&2
      exit 1
      ;;
  esac
  marker=$root/.build/simulator-slot
  if [ "$held" != "$slot" ] || [ "$(cat "$marker" 2>/dev/null)" != "$slot" ]; then
    fresh_slot=1
  fi
  name="OpenDiving pool $slot"
else
  name="OpenDiving $(basename "$root") $(printf '%s' "$root" | shasum | cut -c1-8)"
fi

udid=$(xcrun simctl list devices available |
  awk -v prefix="$name (" '{ sub(/^ +/, "") } index($0, prefix) == 1 {
    rest = substr($0, length(prefix) + 1); print substr(rest, 1, index(rest, ")") - 1); exit }')

if [ -z "$udid" ]; then
  # The newest iPhone Pro this Xcode knows, on the newest iOS runtime installed.
  device_type=$(xcrun simctl list devicetypes |
    sed -n 's/^iPhone \([0-9][0-9]*\) Pro (\(com\.apple\.[^)]*\))$/\1 \2/p' |
    sort -n | tail -n 1 | cut -d' ' -f2)
  if [ -z "$device_type" ]; then
    echo "simulator.sh: this Xcode knows no iPhone Pro device type" >&2
    exit 1
  fi
  udid=$(xcrun simctl create "$name" "$device_type")
elif [ -n "$fresh_slot" ]; then
  # Another checkout's build of the app may have left its data on the device.
  xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
  xcrun simctl erase "$udid" >&2
fi

if [ -n "$fresh_slot" ]; then
  mkdir -p "$root/.build"
  printf '%s\n' "$slot" >"$marker"
fi

printf '%s\n' "$udid"
