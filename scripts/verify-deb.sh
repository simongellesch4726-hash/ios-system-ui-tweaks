#!/usr/bin/env bash
set -euo pipefail

if [[ -n "${THEOS:-}" && -x "$THEOS/toolchain/linux/iphone/bin/lipo" ]]; then
  LIPO="$THEOS/toolchain/linux/iphone/bin/lipo"
elif command -v lipo >/dev/null 2>&1; then
  LIPO="$(command -v lipo)"
else
  echo "lipo is required for Mach-O architecture verification" >&2
  exit 1
fi

for deb in "$@"; do
  echo "==> $deb"
  test -f "$deb"
  test "$(dpkg-deb -f "$deb" Architecture)" = "iphoneos-arm64"

  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  dpkg-deb -x "$deb" "$tmp"

  if find "$tmp" -path '*/var/jb/*' -print -quit | grep -q .; then
    echo "unexpected physical /var/jb payload in $deb" >&2
    exit 1
  fi

  mapfile -t dylibs < <(find "$tmp" -type f -name '*.dylib' -print)
  test "${#dylibs[@]}" -eq 1
  "$LIPO" -info "${dylibs[0]}" | grep -Eq 'arm64'
  if "$LIPO" -info "${dylibs[0]}" | grep -Eq 'arm64e'; then
    echo "unexpected arm64e slice in arm64-targeted package: ${dylibs[0]}" >&2
    exit 1
  fi

  rm -rf "$tmp"
  trap - EXIT
done
