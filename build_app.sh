#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
APP_NAME="HiddenBastard"
APP_PATH="$BUILD_DIR/${APP_NAME}-CLT.app"
VERSION="${1:-1.0.0}"
ARCH="$(uname -m)"

if [[ ! "$VERSION" =~ ^[0-9]+(\.[0-9]+){1,2}$ ]]; then
  echo "Version must contain two or three numeric components (for example 1.0.0)." >&2
  exit 1
fi

case "$ARCH" in
  arm64|x86_64) ;;
  *)
    echo "Unsupported build architecture: $ARCH" >&2
    exit 1
    ;;
esac

SWIFTC="$(xcrun --find swiftc)"
SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
ICONUTIL="$(xcrun --find iconutil)"
APPICONSET="$ROOT_DIR/Resources/AppIcons"
APPLOGO="$ROOT_DIR/Resources/AppLogo.png"

if [[ ! -f "$APPLOGO" ]]; then
  echo "App logo asset is missing: $APPLOGO" >&2
  exit 1
fi

mkdir -p "$BUILD_DIR"
if [[ -e "$APP_PATH" ]]; then
  rm -rf -- "$APP_PATH"
fi

CONTENTS="$APP_PATH/Contents"
RESOURCES="$CONTENTS/Resources"
ICONSET="$RESOURCES/HiddenBastard.iconset"
mkdir -p "$CONTENTS/MacOS" "$ICONSET"

SOURCES=(
  "$ROOT_DIR/AppState.swift"
  "$ROOT_DIR/AppTheme.swift"
  "$ROOT_DIR/CleaningRulesEngine.swift"
  "$ROOT_DIR/ContentView.swift"
  "$ROOT_DIR/DiskSpaceMonitor.swift"
  "$ROOT_DIR/FileScanner.swift"
  "$ROOT_DIR/HiddenBastardApp.swift"
  "$ROOT_DIR/Models.swift"
  "$ROOT_DIR/RuleEditorView.swift"
  "$ROOT_DIR/ScanLocationManager.swift"
  "$ROOT_DIR/SettingsView.swift"
  "$ROOT_DIR/UpdateChecker.swift"
)

"$SWIFTC" \
  -sdk "$SDK_PATH" \
  -target "$ARCH-apple-macosx13.0" \
  -swift-version 5 \
  -parse-as-library \
  -O \
  -framework AppKit \
  -framework SwiftUI \
  -framework UniformTypeIdentifiers \
  -framework UserNotifications \
  -o "$CONTENTS/MacOS/$APP_NAME" \
  "${SOURCES[@]}"

cp "$APPLOGO" "$RESOURCES/AppLogo.png"
cp "$ROOT_DIR/Info.plist" "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable $APP_NAME" "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.hiddenbastard.app" "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleDevelopmentRegion en" "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundlePackageType APPL" "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Set :LSMinimumSystemVersion 13.0" "$CONTENTS/Info.plist"
printf 'APPL????' > "$CONTENTS/PkgInfo"

cp "$APPICONSET/icon_16.png" "$ICONSET/icon_16x16.png"
cp "$APPICONSET/icon_32.png" "$ICONSET/icon_16x16@2x.png"
cp "$APPICONSET/icon_32.png" "$ICONSET/icon_32x32.png"
cp "$APPICONSET/icon_64.png" "$ICONSET/icon_32x32@2x.png"
cp "$APPICONSET/icon_128.png" "$ICONSET/icon_128x128.png"
cp "$APPICONSET/icon_256.png" "$ICONSET/icon_128x128@2x.png"
cp "$APPICONSET/icon_256.png" "$ICONSET/icon_256x256.png"
cp "$APPICONSET/icon_512.png" "$ICONSET/icon_256x256@2x.png"
cp "$APPICONSET/icon_512.png" "$ICONSET/icon_512x512.png"
cp "$APPICONSET/icon_1024.png" "$ICONSET/icon_512x512@2x.png"
"$ICONUTIL" -c icns "$ICONSET" -o "$RESOURCES/AppIcon.icns"
rm \
  "$ICONSET/icon_16x16.png" \
  "$ICONSET/icon_16x16@2x.png" \
  "$ICONSET/icon_32x32.png" \
  "$ICONSET/icon_32x32@2x.png" \
  "$ICONSET/icon_128x128.png" \
  "$ICONSET/icon_128x128@2x.png" \
  "$ICONSET/icon_256x256.png" \
  "$ICONSET/icon_256x256@2x.png" \
  "$ICONSET/icon_512x512.png" \
  "$ICONSET/icon_512x512@2x.png"
rmdir "$ICONSET"

codesign --force --deep --sign - --entitlements "$ROOT_DIR/HiddenBastard.entitlements" "$APP_PATH"
codesign --verify --deep --strict "$APP_PATH"

echo "Built and verified: $APP_PATH"
