#!/usr/bin/env bash
set -euo pipefail

STAGING="${1:?usage: stage-ffmpeg.sh <THEOS_STAGING_DIR>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES="$HERE/../modules/ffmpegkit"

info() { printf '\033[36m==>\033[0m %s\n' "$*"; }

have_frameworks() { ls "$MODULES"/*.framework >/dev/null 2>&1; }

if ! have_frameworks; then
  info "no FFmpegKit frameworks in $MODULES, building them now"
  "$HERE/fetch-ffmpegkit.sh"
fi

have_frameworks || { printf '\033[31merror:\033[0m no FFmpegKit frameworks in %s\n' "$MODULES" >&2; exit 1; }

BUNDLE="$(find "$STAGING" -type d -name 'YouMod.bundle' -print -quit 2>/dev/null || true)"
[ -n "$BUNDLE" ] || { printf '\033[31merror:\033[0m no YouMod.bundle under %s\n' "$STAGING" >&2; exit 1; }

info "staging FFmpegKit into ${BUNDLE#$STAGING}"
for framework in "$MODULES"/*.framework; do
  name="$(basename "$framework")"
  rm -rf "$BUNDLE/$name"
  cp -R "$framework" "$BUNDLE/$name"
  binary="$BUNDLE/$name/${name%.framework}"
  if [ -f "$binary" ] && command -v ldid >/dev/null 2>&1; then
    ldid -S "$binary" 2>/dev/null || true
  fi
done

info "staged $(ls -1d "$BUNDLE"/*.framework | wc -l | tr -d ' ') frameworks ($(du -sh "$MODULES" | cut -f1))"
