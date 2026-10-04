#!/usr/bin/env bash
# Build ClipManager.app bundle from Swift Package Manager output.
# Usage: ./Scripts/build-app.sh [debug|release] [arm64|x86_64|universal]

set -euo pipefail

CONFIG="${1:-release}"
ARCH="${2:-universal}"
PRODUCT_NAME="ClipManager"
BUNDLE_ID="io.clipmanager.app"
PLIST_SRC="Sources/ClipManager/Resources/Info.plist"
ENTITLEMENTS="Sources/ClipManager/Resources/ClipManager.entitlements"
OUTPUT_DIR="build"
APP_DIR="${OUTPUT_DIR}/${PRODUCT_NAME}.app/Contents"

echo "→ Building ${PRODUCT_NAME} (config=${CONFIG}, arch=${ARCH})"

# ---- Build binary ----
if [ "$ARCH" = "universal" ]; then
    ARCH_FLAGS=(--arch arm64 --arch x86_64)
else
    ARCH_FLAGS=(--arch "$ARCH")
fi

swift build -c "$CONFIG" "${ARCH_FLAGS[@]}"
# Ask SwiftPM for the output dir instead of hardcoding it (macOS ships bash 3.2,
# so no ${VAR^} to capitalize "release" → "Release").
BINARY="$(swift build -c "$CONFIG" "${ARCH_FLAGS[@]}" --show-bin-path)/${PRODUCT_NAME}"

# ---- Assemble .app bundle ----
rm -rf "${OUTPUT_DIR}/${PRODUCT_NAME}.app"
mkdir -p "${APP_DIR}/MacOS"
mkdir -p "${APP_DIR}/Resources"

# Binary
cp "$BINARY" "${APP_DIR}/MacOS/${PRODUCT_NAME}"

# Info.plist (version from the release tag / CI run, if provided)
cp "$PLIST_SRC" "${APP_DIR}/Info.plist"
if [ -n "${CLIPMANAGER_VERSION:-}" ]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${CLIPMANAGER_VERSION}" "${APP_DIR}/Info.plist"
fi
BUILD_NUMBER="${CLIPMANAGER_BUILD:-${GITHUB_RUN_NUMBER:-}}"
if [ -n "$BUILD_NUMBER" ]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${BUILD_NUMBER}" "${APP_DIR}/Info.plist"
fi

# App icon: Assets/AppIcon-1024.png → AppIcon.icns (source: Assets/AppIcon.svg, see Scripts/render-icon.mjs)
ICON_SRC="Assets/AppIcon-1024.png"
if [ -f "$ICON_SRC" ]; then
    ICONSET="$(mktemp -d)/AppIcon.iconset"
    mkdir -p "$ICONSET"
    for size in 16 32 128 256 512; do
        sips -z "$size" "$size" "$ICON_SRC" --out "${ICONSET}/icon_${size}x${size}.png" >/dev/null
        sips -z $((size * 2)) $((size * 2)) "$ICON_SRC" --out "${ICONSET}/icon_${size}x${size}@2x.png" >/dev/null
    done
    iconutil -c icns "$ICONSET" -o "${APP_DIR}/Resources/AppIcon.icns"
    rm -rf "$(dirname "$ICONSET")"
fi

echo "→ .app bundle assembled at ${OUTPUT_DIR}/${PRODUCT_NAME}.app"

# ---- Remove extended attributes (common issue on external/network volumes) ----
xattr -cr "${OUTPUT_DIR}/${PRODUCT_NAME}.app" 2>/dev/null || true

# ---- Code signing ----
IDENTITY="${CODESIGN_IDENTITY:-}"

if [ -n "$IDENTITY" ]; then
    echo "→ Signing with identity: ${IDENTITY}"
    codesign \
        --force \
        --options runtime \
        --entitlements "$ENTITLEMENTS" \
        --sign "$IDENTITY" \
        --timestamp \
        "${OUTPUT_DIR}/${PRODUCT_NAME}.app"
    echo "→ Signed successfully"
else
    # Ad-hoc sign for local testing
    echo "→ No CODESIGN_IDENTITY set — using ad-hoc signature"
    codesign \
        --force \
        --options runtime \
        --entitlements "$ENTITLEMENTS" \
        --sign "-" \
        "${OUTPUT_DIR}/${PRODUCT_NAME}.app"
fi

echo "✓ Build complete: ${OUTPUT_DIR}/${PRODUCT_NAME}.app"
