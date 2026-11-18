#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
VERSION="${1:-1.1.0}"
APP_NAME="HiddenBastard"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
BUILD_DIR="$ROOT_DIR/build"
APP_PATH="$BUILD_DIR/${APP_NAME}-CLT.app"
STAGING="$BUILD_DIR/dmg_staging_clt"
DMG_PATH="$BUILD_DIR/$DMG_NAME"

echo "Building Hidden Bastard v${VERSION}..."
bash "$ROOT_DIR/build_app.sh" "$VERSION"

echo "Creating DMG..."
mkdir -p "$STAGING"
if [[ -e "$STAGING/${APP_NAME}.app" ]]; then
  rm -rf -- "$STAGING/${APP_NAME}.app"
fi
ditto "$APP_PATH" "$STAGING/${APP_NAME}.app"
ln -sfn /Applications "$STAGING/Applications"

if hdiutil create \
  -volname "Hidden Bastard ${VERSION}" \
  -srcfolder "$STAGING" \
  -ov \
  -format UDZO \
  "$DMG_PATH"; then
  echo "Done: $DMG_PATH"
else
  echo "DMG creation failed." >&2
  exit 1
fi

rm -rf -- "$STAGING"
