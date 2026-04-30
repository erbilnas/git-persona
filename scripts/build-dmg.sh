#!/usr/bin/env bash
# Build Release GitPersona.app and wrap it in a compressed DMG with /Applications symlink.
# Optional: Developer ID sign + notarize (recommended for distribution outside your Mac).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCHEME="GitPersona"
CONFIGURATION="Release"
DERIVED="${ROOT}/build/DerivedDataRelease"
APP="${DERIVED}/Build/Products/${CONFIGURATION}/GitPersona.app"
STAGING="${ROOT}/dist/staging"
VOLNAME_BASE="GitPersona"

SIGN_IDENTITY="${SIGN_IDENTITY:-}" # e.g. "Developer ID Application: Your Name (TEAMID)"
NOTARY_PROFILE="${NOTARY_PROFILE:-}" # `notarytool store-credentials` profile name

echo "==> Building ${CONFIGURATION}…"
xcodebuild \
  -project "${ROOT}/GitPersona.xcodeproj" \
  -scheme "${SCHEME}" \
  -configuration "${CONFIGURATION}" \
  -derivedDataPath "${DERIVED}" \
  build

if [[ ! -d "${APP}" ]]; then
  echo "error: missing ${APP}" >&2
  exit 1
fi

MARKETING_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${APP}/Contents/Info.plist" 2>/dev/null || echo "0.0.0")"
BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "${APP}/Contents/Info.plist" 2>/dev/null || echo "0")"
echo "==> Version ${MARKETING_VERSION} (${BUILD_NUMBER})"

DMG_OUT="${ROOT}/dist/GitPersona-${MARKETING_VERSION}.dmg"
VOLNAME="${VOLNAME_BASE} ${MARKETING_VERSION}"

rm -rf "${STAGING}"
mkdir -p "${STAGING}"
ditto "${APP}" "${STAGING}/GitPersona.app"
ln -sf /Applications "${STAGING}/Applications"

if [[ -n "${SIGN_IDENTITY}" ]]; then
  echo "==> Signing app (${SIGN_IDENTITY})…"
  codesign --deep --force --options runtime --sign "${SIGN_IDENTITY}" "${STAGING}/GitPersona.app"
else
  echo "==> Skipping app codesign (set SIGN_IDENTITY to enable)."
fi

mkdir -p "$(dirname "${DMG_OUT}")"
rm -f "${DMG_OUT}"
rm -f "${ROOT}/dist/GitPersona.dmg"

echo "==> Creating DMG…"
hdiutil create \
  -volname "${VOLNAME}" \
  -srcfolder "${STAGING}" \
  -ov \
  -format UDZO \
  "${DMG_OUT}"

if [[ -n "${SIGN_IDENTITY}" ]]; then
  echo "==> Signing DMG…"
  codesign --sign "${SIGN_IDENTITY}" "${DMG_OUT}"
fi

if [[ -n "${NOTARY_PROFILE}" ]]; then
  echo "==> Submitting for notarization…"
  xcrun notarytool submit "${DMG_OUT}" --keychain-profile "${NOTARY_PROFILE}" --wait
  echo "==> Stapling…"
  xcrun stapler staple "${DMG_OUT}"
else
  echo "==> Skipping notarization (set NOTARY_PROFILE to enable)."
fi

(
  cd "${ROOT}/dist"
  ln -sf "$(basename "${DMG_OUT}")" "GitPersona.dmg"
)

echo "Done: ${DMG_OUT}"
echo "    Alias: ${ROOT}/dist/GitPersona.dmg"
