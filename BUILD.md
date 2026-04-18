# Building Hidden Bastard

## Requirements

- macOS 13.0 Ventura or later
- Xcode 15 or later

## Build from Source

```bash
git clone https://github.com/ghostintheprompt/hidden-bastard
cd hidden-bastard

# Debug build
xcodebuild -project HiddenBastard.xcodeproj -scheme HiddenBastard -configuration Debug build

# Release build
xcodebuild -project HiddenBastard.xcodeproj -scheme HiddenBastard -configuration Release build
```

## Create a DMG

```bash
./make_dmg.sh 1.0.0
# Output: build/HiddenBastard-1.0.0.dmg
```

## Installing

1. Open the DMG
2. Drag Hidden Bastard to Applications
3. Right-click → Open on first launch (required for unsigned apps)

## First Launch

macOS will warn that the app is from an unidentified developer. This is normal for open-source apps distributed outside the App Store. Right-click → Open bypasses this permanently.

## Troubleshooting

**"Cannot access files"** — go to System Settings → Privacy & Security → Full Disk Access → add Hidden Bastard

**Build errors** — make sure all `.swift` files are added to the Xcode target (Sources build phase)
