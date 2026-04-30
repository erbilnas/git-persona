#!/usr/bin/env bash
# Rasterize docs/logo.svg into AppIcon.appiconset (macOS bundle icon) and into
# BrandLogo / MenuBarMark image sets. Single source for all: docs/logo.svg.
# Prefers rsvg-convert (`brew install librsvg`). Otherwise uses qlmanage -t -i (icon mode);
# plain qlmanage thumbnails are not suitable for app icons.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SVG="${ROOT}/docs/logo.svg"
ICONSET="${ROOT}/GitPersona/Assets.xcassets/AppIcon.appiconset"
BRAND="${ROOT}/GitPersona/Assets.xcassets/BrandLogo.imageset"
MENU="${ROOT}/GitPersona/Assets.xcassets/MenuBarMark.imageset"
STAGING="${ROOT}/build/logo-raster-temp"

if [[ ! -f "${SVG}" ]]; then
  echo "error: missing ${SVG}" >&2
  exit 1
fi

mkdir -p "${STAGING}"

raster_master() {
  local out="$1"
  if command -v rsvg-convert >/dev/null 2>&1; then
    rsvg-convert -w 1024 -h 1024 "${SVG}" -o "${out}"
  else
    rm -f "${STAGING}/"*.png 2>/dev/null || true
    # -i: icon mode (fills the canvas). Without -i, Quick Look uses document-style
    # thumbnails (small graphic, often top-left on white), which breaks AppIcon previews.
    qlmanage -t -i -s 1024 -o "${STAGING}" "${SVG}" >/dev/null
    local ql="${STAGING}/logo.svg.png"
    if [[ ! -f "${ql}" ]]; then
      echo "error: qlmanage did not produce ${ql}. Install librsvg for rsvg-convert." >&2
      exit 1
    fi
    cp "${ql}" "${out}"
  fi
}

MASTER="${STAGING}/master-1024.png"
raster_master "${MASTER}"

resize_to() {
  local px="$1"
  local dest="$2"
  sips -z "${px}" "${px}" "${MASTER}" --out "${dest}" >/dev/null
}

echo "==> Writing AppIcon PNGs from docs/logo.svg to ${ICONSET}"
resize_to 16 "${ICONSET}/icon16.png"
resize_to 32 "${ICONSET}/icon16@2x.png"
resize_to 32 "${ICONSET}/icon32.png"
resize_to 64 "${ICONSET}/icon32@2x.png"
resize_to 128 "${ICONSET}/icon128.png"
resize_to 256 "${ICONSET}/icon128@2x.png"
resize_to 256 "${ICONSET}/icon256.png"
resize_to 512 "${ICONSET}/icon256@2x.png"
resize_to 512 "${ICONSET}/icon512.png"
resize_to 1024 "${ICONSET}/icon512@2x.png"

mkdir -p "${BRAND}" "${MENU}"
echo "==> Writing BrandLogo + MenuBarMark"
resize_to 128 "${BRAND}/logo128.png"
resize_to 256 "${BRAND}/logo256.png"
resize_to 36 "${MENU}/menubar36.png"
resize_to 72 "${MENU}/menubar72.png"

echo "==> Done."
