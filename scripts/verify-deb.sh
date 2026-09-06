#!/usr/bin/env bash
set -euo pipefail

for deb in "$@"; do
  echo "==> $deb"
  test -f "$deb"
  test "$(dpkg-deb -f "$deb" Architecture)" = "iphoneos-arm64e"

  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  dpkg-deb -x "$deb" "$tmp"

  if find "$tmp" -path '*/var/jb/*' -print -quit | grep -q .; then
    echo "unexpected physical /var/jb payload in $deb" >&2
    exit 1
  fi

  dylibs=( $(find "$tmp" -type f -name '*.dylib' -print) )
  test "${#dylibs[@]}" -eq 1
  lipo -info "${dylibs[0]}" | grep -Eq 'arm64e'

  rm -rf "$tmp"
  trap - EXIT
done
