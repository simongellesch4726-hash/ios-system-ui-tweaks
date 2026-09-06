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

status=0
for deb in "$@"; do
  echo "==> $deb"

  if [[ ! -f "$deb" ]]; then
    echo "missing package: $deb" >&2
    status=1
    continue
  fi

  arch="$(dpkg-deb -f "$deb" Architecture)"
  if [[ "$arch" != "iphoneos-arm64e" ]]; then
    echo "unexpected package architecture: $arch" >&2
    status=1
    continue
  fi

  tmp="$(mktemp -d)"
  if ! dpkg-deb -x "$deb" "$tmp"; then
    rm -rf "$tmp"
    status=1
    continue
  fi

  if find "$tmp" -path '*/var/jb/*' -print -quit | grep -q .; then
    echo "unexpected physical /var/jb payload in $deb" >&2
    rm -rf "$tmp"
    status=1
    continue
  fi

  mapfile -t dylibs < <(find "$tmp" -type f -name '*.dylib' -print)
  if [[ "${#dylibs[@]}" -ne 1 ]]; then
    echo "expected exactly one dylib payload, found ${#dylibs[@]}" >&2
    rm -rf "$tmp"
    status=1
    continue
  fi

  if ! arch_info="$($LIPO -info "${dylibs[0]}")"; then
    echo "lipo failed for ${dylibs[0]}" >&2
    rm -rf "$tmp"
    status=1
    continue
  fi
  echo "$arch_info"

  if ! grep -Eq '(^|[^[:alnum:]])arm64e([^[:alnum:]]|$)' <<<"$arch_info"; then
    echo "expected arm64e Mach-O slice in ${dylibs[0]}" >&2
    rm -rf "$tmp"
    status=1
    continue
  fi

  rm -rf "$tmp"
done

exit "$status"
