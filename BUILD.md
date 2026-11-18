# Building Hidden Bastard

## Requirements

- macOS 13.0 Ventura or later
- Apple's Command Line Tools (Swift, the macOS SDK, `iconutil`, and `codesign`)
- A full Xcode installation is not required

## Build from Source

```bash
git clone https://github.com/ghostintheprompt/hidden-bastard
cd hidden-bastard

# Build for this Mac's CPU architecture
bash ./build_app.sh

# Optional version number
bash ./build_app.sh 1.1.0
```

The app is created at `build/HiddenBastard-CLT.app`. The script compiles the Swift sources with `swiftc`, builds the `.icns` icon using `iconutil`, assembles the app bundle, and signs it locally with an ad-hoc signature. It does not use `xcodebuild`, `actool`, or `ibtool`.

The logo and app icon inputs are regular PNG files under `Resources/`; there are no asset catalogs or Xcode project files in the build path.

## Create a DMG

```bash
bash ./make_dmg.sh 1.1.0
# Output: build/HiddenBastard-1.1.0.dmg
```

The DMG builder uses the Command Line Tools build and preserves other files under `build/`.

## Installing

1. Open the DMG
2. Drag Hidden Bastard to Applications
3. Right-click → Open on first launch (required for unsigned apps)

The command-line build is signed ad hoc, not notarized. macOS may require manually approving the app on first launch.

## Troubleshooting

**"Cannot access files"** — go to System Settings → Privacy & Security → Full Disk Access → add Hidden Bastard

**Build errors** — make sure the Command Line Tools are installed and selected with `xcode-select -p`
