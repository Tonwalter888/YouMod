#!/usr/bin/env bash
set -euo pipefail

STAGING="${1:?usage: stage-ffmpeg.sh <THEOS_STAGING_DIR>}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE_REPO="${YOUMOD_FFMPEG_RELEASE_REPO:-Tonwalter888/Tonwalter888.github.io}"
RELEASE_BASE_URL="${YOUMOD_FFMPEG_RELEASE_BASE_URL:-https://github.com/$RELEASE_REPO/releases/download/ffmpegkit-latest}"
CACHE_ROOT="${YOUMOD_FFMPEG_CACHE_DIR:-$ROOT/.cache/ffmpegkit}"
MODULES_CACHE="$CACHE_ROOT/modules"
ARCHIVE_NAME='ffmpegkit-ios-arm64-latest.tar.gz'
EXPECTED_BUILD_ARGS='--arch=arm64 --xcframework --target=14.0 --enable-lib-ios-zlib --enable-lib-ios-libiconv'
FRAMEWORKS=(ffmpegkit libavcodec libavdevice libavfilter libavformat libavutil libswresample libswscale)
DOWNLOAD_TMP=''

info() { printf '\033[36m==>\033[0m %s\n' "$*"; }
die()  { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }
cleanup_download() { [[ -z "$DOWNLOAD_TMP" ]] || rm -rf "$DOWNLOAD_TMP"; }
trap cleanup_download EXIT

have_frameworks() {
  local framework
  for framework in "${FRAMEWORKS[@]}"; do
    [[ -f "$MODULES_CACHE/ffmpegkit/$framework.framework/$framework" ]] || return 1
  done
  [[ -f "$MODULES_CACHE/ffmpegkit/.youmod-source-build" ]]
}

marker_matches() {
  local version="$1" tag build_args
  tag="$(sed -n 's/^tag=//p' "$MODULES_CACHE/ffmpegkit/.youmod-source-build" 2>/dev/null || true)"
  build_args="$(sed -n 's/^build_args=//p' "$MODULES_CACHE/ffmpegkit/.youmod-source-build" 2>/dev/null || true)"
  [[ "$tag" == "$version" && "$build_args" == "$EXPECTED_BUILD_ARGS" ]]
}

download_release() {
  local version archive checksum
  DOWNLOAD_TMP="$(mktemp -d "$CACHE_ROOT/download.XXXXXX")"

  curl --fail --silent --show-error --location --retry 3 \
    "$RELEASE_BASE_URL/ffmpegkit-version.txt" -o "$DOWNLOAD_TMP/version.txt"
  version="$(tr -d '\r\n' < "$DOWNLOAD_TMP/version.txt")"
  [[ "$version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+([.-][A-Za-z0-9._-]+)?$ ]] || die "unexpected FFmpegKit release version: $version"

  archive="$DOWNLOAD_TMP/$ARCHIVE_NAME"
  checksum="$archive.sha256"
  curl --fail --silent --show-error --location --retry 3 \
    "$RELEASE_BASE_URL/$ARCHIVE_NAME" -o "$archive"
  curl --fail --silent --show-error --location --retry 3 \
    "$RELEASE_BASE_URL/$ARCHIVE_NAME.sha256" -o "$checksum"
  (cd "$DOWNLOAD_TMP" && shasum -a 256 -c "$(basename "$checksum")") || die 'FFmpegKit release checksum verification failed'

  mkdir -p "$DOWNLOAD_TMP/extracted"
  tar -xzf "$archive" -C "$DOWNLOAD_TMP/extracted"
  [[ -f "$DOWNLOAD_TMP/extracted/ffmpegkit/.youmod-source-build" ]] || die 'FFmpegKit release archive is missing its build marker'

  local tag build_args framework
  tag="$(sed -n 's/^tag=//p' "$DOWNLOAD_TMP/extracted/ffmpegkit/.youmod-source-build" 2>/dev/null || true)"
  build_args="$(sed -n 's/^build_args=//p' "$DOWNLOAD_TMP/extracted/ffmpegkit/.youmod-source-build" 2>/dev/null || true)"
  [[ "$tag" == "$version" ]] || die "release metadata version $version does not match archive tag $tag"
  [[ "$build_args" == "$EXPECTED_BUILD_ARGS" ]] || die "unexpected FFmpegKit build arguments: $build_args"
  for framework in "${FRAMEWORKS[@]}"; do
    [[ -f "$DOWNLOAD_TMP/extracted/ffmpegkit/$framework.framework/$framework" ]] || die "release archive is missing $framework.framework/$framework"
  done

  rm -rf "$MODULES_CACHE"
  mkdir -p "$MODULES_CACHE"
  mv "$DOWNLOAD_TMP/extracted/ffmpegkit" "$MODULES_CACHE/ffmpegkit"
  info "downloaded FFmpegKit release $version"
}

mkdir -p "$CACHE_ROOT"
version="$(curl --fail --silent --show-error --location --retry 3 \
  "$RELEASE_BASE_URL/ffmpegkit-version.txt" | tr -d '\r\n')"
[[ -n "$version" ]] || die 'FFmpegKit release version is empty'

if ! have_frameworks || ! marker_matches "$version"; then
  info "fetching FFmpegKit $version from the rolling release"
  download_release
else
  info "using cached FFmpegKit release $version"
fi

BUNDLE="$(find "$STAGING" -type d -name 'YouMod.bundle' -print -quit 2>/dev/null || true)"
[[ -n "$BUNDLE" ]] || die "no YouMod.bundle under $STAGING"

info "staging FFmpegKit into ${BUNDLE#$STAGING}"
for framework in "${FRAMEWORKS[@]}"; do
  source_path="$MODULES_CACHE/ffmpegkit/$framework.framework"
  target="$BUNDLE/$framework.framework"
  rm -rf "$target"
  cp -R "$source_path" "$target"
  binary="$target/$framework"
  if [[ -f "$binary" ]] && command -v ldid >/dev/null 2>&1; then
    ldid -S "$binary" 2>/dev/null || true
  fi
done

info "staged ${#FRAMEWORKS[@]} FFmpegKit frameworks ($(du -sh "$MODULES_CACHE" | cut -f1))"
