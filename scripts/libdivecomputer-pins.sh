#!/bin/sh
# Fails unless the two releases project.yml pins name one libdivecomputer commit: the reader's
# (LIBDIVECOMPUTER_COMMIT in divejson-c) and libdc-swift's (its libdivecomputer submodule). The
# app links the reader against libdc-swift's copy, and the reader's mapping is checked against
# the parsers of the commit it names.
set -eu

root=$(cd "$(dirname "$0")/.." && pwd -P)

# The exactVersion under a package key in project.yml.
pin() {
  awk -v key="$1:" '$1 == key { found = 1; next }
    found && $1 == "exactVersion:" { print $2; exit }' "$root/project.yml"
}

libdc_swift=$(pin LibDCSwift)
reader=$(pin LibDiveJSON)
if [ -z "$libdc_swift" ] || [ -z "$reader" ]; then
  echo "libdivecomputer-pins.sh: project.yml pins no LibDCSwift or no LibDiveJSON" >&2
  exit 1
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
git -C "$work" init -q

git -C "$work" fetch -q --depth 1 https://github.com/deepsealabs/libdc-swift \
  "refs/tags/$libdc_swift"
submodule=$(git -C "$work" ls-tree FETCH_HEAD libdivecomputer | awk '{ print $3 }')

git -C "$work" fetch -q --depth 1 https://github.com/divejson/divejson-c "refs/tags/v$reader"
vendored=$(git -C "$work" show FETCH_HEAD:LIBDIVECOMPUTER_COMMIT | tr -d '[:space:]')

if [ -z "$submodule" ] || [ "$submodule" != "$vendored" ]; then
  echo "libdc-swift $libdc_swift carries libdivecomputer ${submodule:-(none)}," >&2
  echo "divejson-c $reader was built for $vendored: move the two pins together" >&2
  exit 1
fi
echo "libdc-swift $libdc_swift and divejson-c $reader both name libdivecomputer $vendored"
