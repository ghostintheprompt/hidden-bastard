# Building Hidden Bastard for macOS

This guide walks you through building and distributing Hidden Bastard as an attractive macOS application.

## Prerequisites

1. **macOS 11.0 (Big Sur) or later**
2. **Xcode 13.0 or later** (download from Mac App Store)
3. **Apple Developer Account** (for code signing and distribution)
   - Individual: Free for development, $99/year for distribution
   - Organization: $99/year

## Quick Start

### Option 1: Open in Xcode (Recommended)

```bash
# Clone or navigate to the project
cd hidden_bastard

# Open in Xcode
open HiddenBastard.xcodeproj
```

In Xcode:
1. Select the "HiddenBastard" scheme
2. Choose "My Mac" as the destination
3. Click Run (⌘R) to build and launch

### Option 2: Command Line Build

```bash
# Build the project
xcodebuild -project HiddenBastard.xcodeproj \
  -scheme HiddenBastard \
  -configuration Release \
  build

# The app will be in:
# build/Release/HiddenBastard.app
```

## Code Signing Setup

To distribute your app, you need to sign it with a valid Apple Developer certificate.

### 1. Join Apple Developer Program

Visit https://developer.apple.com/programs/ and enroll ($99/year)

### 2. Create Certificates

1. Open Xcode → Preferences → Accounts
2. Add your Apple ID
3. Select your team → Manage Certificates
4. Click "+" → "Apple Development" (for testing)
5. Click "+" → "Developer ID Application" (for distribution outside Mac App Store)

### 3. Configure Code Signing in Xcode

1. Open the project in Xcode
2. Select the project in the navigator
3. Select the "HiddenBastard" target
4. Go to "Signing & Capabilities"
5. Select your Team from the dropdown
6. Xcode will automatically provision the app

## Building for Distribution

### Option 1: Mac App Store Distribution

1. **Archive the app**:
   - In Xcode: Product → Archive
   - Wait for the build to complete
   - Organizer window will open

2. **Distribute to App Store**:
   - Click "Distribute App"
   - Select "App Store Connect"
   - Follow the wizard

3. **Submit for review**:
   - Visit https://appstoreconnect.apple.com
   - Create app listing with screenshots, description
   - Submit for review

**Pros**: Built-in payment processing, automatic updates, App Store visibility
**Cons**: 30% commission, review process (1-3 days), strict guidelines

### Option 2: Direct Distribution (Shareware)

This is ideal for shareware distribution with your own licensing system.

#### Step 1: Create a Notarized Build

```bash
# Archive the app
xcodebuild -project HiddenBastard.xcodeproj \
  -scheme HiddenBastard \
  -configuration Release \
  -archivePath build/HiddenBastard.xcarchive \
  archive

# Export the app
xcodebuild -exportArchive \
  -archivePath build/HiddenBastard.xcarchive \
  -exportPath build/Export \
  -exportOptionsPlist ExportOptions.plist
```

#### Step 2: Notarize with Apple

```bash
# Create a DMG (optional but recommended)
hdiutil create -volname "Hidden Bastard" \
  -srcfolder build/Export/HiddenBastard.app \
  -ov -format UDZO \
  HiddenBastard.dmg

# Submit for notarization
xcrun notarytool submit HiddenBastard.dmg \
  --apple-id "your@email.com" \
  --password "app-specific-password" \
  --team-id "YOUR_TEAM_ID" \
  --wait

# Staple the notarization ticket
xcrun stapler staple HiddenBastard.dmg
```

#### Step 3: Distribute

Upload `HiddenBastard.dmg` to your website, GitHub releases, or distribution platform.

## Shareware Licensing

The app includes built-in trial/licensing functionality:

### Built-in License System

Located in `SettingsView.swift`:

```swift
// License keys starting with these prefixes are valid
let validPrefixes = ["HBFD", "TEST", "DEMO"]
```

### Recommended Third-Party Solutions

For production shareware:

1. **Paddle** (https://paddle.com)
   - All-in-one: Licensing + payments + VAT handling
   - $19.99 one-time: ~70% after fees
   - Recommended for simplicity

2. **Gumroad** (https://gumroad.com)
   - Simple setup, 10% fee
   - Easy license key generation
   - Good for indie developers

3. **DevMate** (https://devmate.com)
   - Specialized for Mac apps
   - Includes auto-update framework (Sparkle)
   - Analytics and crash reporting

4. **Custom System**
   - Generate license keys server-side
   - Validate in app using cryptographic signatures
   - See: https://github.com/andrewlowson/CocoaFob

## Adding Auto-Updates

Use Sparkle framework for automatic updates:

```bash
# Add via Swift Package Manager in Xcode
# URL: https://github.com/sparkle-project/Sparkle
```

## App Icon Creation

The app currently uses SF Symbols. For a polished look:

1. **Design a 1024x1024 icon** (use Figma, Sketch, or Affinity Designer)
2. **Use app icon generators**:
   - https://appicon.co
   - https://www.appicon.build
3. **Add to Xcode**:
   - Open Assets.xcassets (you'll need to create this)
   - Drag icons into AppIcon slot

## Marketing Assets

For successful shareware distribution, create:

1. **Screenshots** (1280x800 recommended)
   - Main scan view
   - File list with results
   - Settings/licensing screen
   - System monitor view

2. **Demo Video** (30-60 seconds)
   - Screen recording showing scan → results → deletion
   - Use QuickTime Player for screen recording
   - Edit with iMovie or Final Cut Pro

3. **Website Landing Page**
   - Problem statement (disk space issues)
   - Features list
   - Screenshots/video
   - Download button
   - Purchase button ($19.99)
   - Support/FAQ

## Pricing Recommendations

Based on similar utilities:

- **DaisyDisk**: $9.99
- **CleanMyMac X**: $34.95/year
- **DriveDx**: $20
- **Recommended for Hidden Bastard**: $14.99 - $24.99 one-time

## Testing Checklist

Before release:

- [ ] Test on macOS 11, 12, 13, 14, 15
- [ ] Test Full Disk Access permissions
- [ ] Test file deletion (create test files first!)
- [ ] Test license activation/deactivation
- [ ] Verify app is properly sandboxed
- [ ] Test update mechanism (if using Sparkle)
- [ ] Verify no crashes in Console.app
- [ ] Test on both Intel and Apple Silicon Macs

## Troubleshooting

### "App is damaged and can't be opened"
- Your app isn't notarized. Follow notarization steps above.

### "Cannot access files"
- Grant Full Disk Access in System Preferences → Security & Privacy → Privacy → Full Disk Access

### Code signing errors
- Verify your Developer ID certificate is valid
- Check entitlements file is properly configured

## Distribution Checklist

- [ ] Code signed with Developer ID
- [ ] Notarized by Apple
- [ ] DMG created with attractive volume icon
- [ ] License key system integrated with payment processor
- [ ] Website/landing page created
- [ ] Analytics/crash reporting (optional but recommended)
- [ ] Auto-update system (Sparkle) configured

## Resources

- **Apple Developer Documentation**: https://developer.apple.com/documentation/
- **Xcode Help**: https://developer.apple.com/xcode/
- **Notarization Guide**: https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution
- **App Sandbox**: https://developer.apple.com/documentation/security/app_sandbox

## Support

For issues with the build process, check:
1. Xcode version is 13.0 or later
2. macOS deployment target is set to 11.0
3. All Swift files are added to the target
4. Entitlements file is properly configured

Good luck with your shareware distribution!
