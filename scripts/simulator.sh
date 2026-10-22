#!/bin/sh
# Prints the UDID of this checkout's own iPhone simulator, creating it on first use.
#
# One simulator per checkout, named after its path, because two `xcodebuild test` runs
# installing app.opendiving.ios on the same device kill each other's test host - and
# worktrees of this repository run their tests concurrently on one Mac.
set -eu

root=$(cd "$(dirname "$0")/.." && pwd -P)
name="OpenDiving $(basename "$root") $(printf '%s' "$root" | shasum | cut -c1-8)"

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
fi

printf '%s\n' "$udid"
