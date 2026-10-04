#!/usr/bin/env bash
# Creates a distributable DMG (app + Applications shortcut) from build/ClipManager.app.
# Uses only hdiutil, so it works on a clean CI runner without extra tools.

set -euo pipefail

PRODUCT_NAME="ClipManager"
VERSION="${CLIPMANAGER_VERSION:-1.0.0}"
OUTPUT_DIR="build"
APP="${OUTPUT_DIR}/${PRODUCT_NAME}.app"
DMG_NAME="${PRODUCT_NAME}-${VERSION}.dmg"
DMG_OUT="${OUTPUT_DIR}/${DMG_NAME}"

[ -d "$APP" ] || { echo "Error: ${APP} not found. Run build-app.sh first."; exit 1; }

echo "→ Creating DMG: ${DMG_NAME}"

STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT

ditto "$APP" "${STAGING}/${PRODUCT_NAME}.app"
ln -s /Applications "${STAGING}/Applications"
rm -f "$DMG_OUT"

# hdiutil occasionally fails with "Resource busy" on CI runners — retry a few times
for attempt in 1 2 3; do
    if hdiutil create \
        -volname "${PRODUCT_NAME} ${VERSION}" \
        -srcfolder "$STAGING" \
        -fs HFS+ \
        -format UDZO \
        -ov \
        "$DMG_OUT"; then
        break
    fi
    [ "$attempt" -eq 3 ] && { echo "Error: hdiutil failed"; exit 1; }
    echo "hdiutil failed (attempt ${attempt}), retrying…"
    sleep 5
done

if [ -n "${CODESIGN_IDENTITY:-}" ]; then
    codesign --force --sign "$CODESIGN_IDENTITY" --timestamp "$DMG_OUT"
fi

echo "✓ DMG: ${DMG_OUT}"
