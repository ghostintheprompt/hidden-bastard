#!/bin/bash
set -euo pipefail
# Hidden Bastard — DMG builder for GitHub Releases
# Usage: ./make_dmg.sh [version]
# Example: ./make_dmg.sh 1.0.0

VERSION=${1:-"1.1.0"}
APP_NAME="HiddenBastard"
DMG_NAME="HiddenBastard-${VERSION}.dmg"
BUILD_DIR="$(pwd)/build"
APP_PATH="${BUILD_DIR}/${APP_NAME}.app"

echo "Building Hidden Bastard v${VERSION}..."

# Clean build
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# Build Release
if ! xcodebuild \
  -project HiddenBastard.xcodeproj \
  -scheme HiddenBastard \
  -configuration Release \
  -derivedDataPath "${BUILD_DIR}/DerivedData" \
  CONFIGURATION_BUILD_DIR="${BUILD_DIR}" \
  build; then
  echo "Build failed. Aborting."
  exit 1
fi

# Xcode may produce only a linker-signed executable when no Developer ID is
# configured. Seal the finished bundle so macOS can validate its resources.
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "${APP_PATH}/Contents/Info.plist"
codesign --force --deep --sign - "${APP_PATH}"
codesign --verify --deep --strict --verbose=2 "${APP_PATH}"

echo "Build succeeded. Creating DMG..."

# Create staging folder
STAGING="${BUILD_DIR}/dmg_staging"
mkdir -p "${STAGING}"
ditto "${APP_PATH}" "${STAGING}/${APP_NAME}.app"
ln -s /Applications "${STAGING}/Applications"

# Create DMG
if hdiutil create \
  -volname "Hidden Bastard ${VERSION}" \
  -srcfolder "${STAGING}" \
  -ov \
  -format UDZO \
  "${BUILD_DIR}/${DMG_NAME}"; then
  echo ""
  echo "Done: ${BUILD_DIR}/${DMG_NAME}"
  echo ""
  echo "Next steps:"
  echo "  1. Test the DMG: open ${BUILD_DIR}/${DMG_NAME}"
  echo "  2. Tag release:  git tag v${VERSION} && git push origin v${VERSION}"
  echo "  3. Upload ${DMG_NAME} to GitHub Releases"
else
  echo "DMG creation failed."
  exit 1
fi
