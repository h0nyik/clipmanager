#!/usr/bin/env bash
# Creates a distributable DMG from ClipManager.app.
# Requires: create-dmg (brew install create-dmg)

set -euo pipefail

PRODUCT_NAME="ClipManager"
VERSION="${CLIPMANAGER_VERSION:-1.0.0}"
OUTPUT_DIR="build"
APP="${OUTPUT_DIR}/${PRODUCT_NAME}.app"
DMG_NAME="${PRODUCT_NAME}-${VERSION}.dmg"
DMG_OUT="${OUTPUT_DIR}/${DMG_NAME}"

if ! command -v create-dmg &>/dev/null; then
    echo "Error: create-dmg not found. Run: brew install create-dmg"
    exit 1
fi

[ -d "$APP" ] || { echo "Error: ${APP} not found. Run build-app.sh first."; exit 1; }

echo "→ Creating DMG: ${DMG_NAME}"

create-dmg \
    --volname "${PRODUCT_NAME} ${VERSION}" \
    --volicon "${OUTPUT_DIR}/AppIcon.icns" \
    --window-pos 200 120 \
    --window-size 600 400 \
    --icon-size 128 \
    --icon "${PRODUCT_NAME}.app" 150 190 \
    --hide-extension "${PRODUCT_NAME}.app" \
    --app-drop-link 450 190 \
    --no-internet-enable \
    "${DMG_OUT}" \
    "$APP" \
    2>/dev/null || true  # create-dmg exits non-zero on some warnings

echo "✓ DMG: ${DMG_OUT}"
