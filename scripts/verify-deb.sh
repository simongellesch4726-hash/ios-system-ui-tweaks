#!/usr/bin/env bash
set -euo pipefail

for deb in "$@"; do
  echo "==> $deb"
  test -f "$deb"
  dpkg-deb -f "$deb" Architecture | grep -qx 'iphoneos-arm64e'
  tmp="$(mktemp -d)"
  dpkg-deb -x "$deb" "$tmp"
  if find "$tmp" -path '*/var/jb/*' -print -quit | grep -q .; then
    echo "unexpected physical /var/jb payload in $deb" >&2
    exit 1
  fi
  dylib="$(find "$tmp" -type f -name '*.dylib' | head -n1 || true)"
  test -n "$dylib"
  lipo -info "$dylib" | grep -q 'arm64e'
  rm -rf "$tmp"
done
