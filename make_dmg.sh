#!/bin/bash
# Hidden Bastard — DMG builder for GitHub Releases
# Usage: ./make_dmg.sh [version]
# Example: ./make_dmg.sh 1.0.0

VERSION=${1:-"1.0.0"}
APP_NAME="HiddenBastard"
DMG_NAME="HiddenBastard-${VERSION}.dmg"
BUILD_DIR="$(pwd)/build"
APP_PATH="${BUILD_DIR}/${APP_NAME}.app"

echo "Building Hidden Bastard v${VERSION}..."

# Clean build
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# Build Release
xcodebuild \
  -project HiddenBastard.xcodeproj \
  -scheme HiddenBastard \
  -configuration Release \
  CONFIGURATION_BUILD_DIR="${BUILD_DIR}" \
  build

if [ $? -ne 0 ]; then
  echo "Build failed. Aborting."
  exit 1
fi

echo "Build succeeded. Creating DMG..."

# Create staging folder
STAGING="${BUILD_DIR}/dmg_staging"
mkdir -p "${STAGING}"
cp -R "${APP_PATH}" "${STAGING}/"
ln -s /Applications "${STAGING}/Applications"

# Create DMG
hdiutil create \
  -volname "Hidden Bastard ${VERSION}" \
  -srcfolder "${STAGING}" \
  -ov \
  -format UDZO \
  "${BUILD_DIR}/${DMG_NAME}"

if [ $? -eq 0 ]; then
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
