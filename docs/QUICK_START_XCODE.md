# Quick Start: Fixing Xcode Project

## Current Status
✅ All code implemented and ready
⚠️ Xcode project needs file references updated

## 5-Minute Fix

### Option 1: GUI Method (Recommended)

1. **Open Xcode**:
   ```bash
   open HiddenBastard.xcodeproj
   ```

2. **Remove missing file** (Assets.swift):
   - Find `Assets.swift` in Project Navigator (it will appear in RED)
   - Right-click → Delete
   - Choose "Remove Reference" (not "Move to Trash")

3. **Add new files**:
   - Right-click on project root folder
   - Select "Add Files to 'HiddenBastard'..."
   - Hold Command (⌘) and select these 4 files:
     - `ScanLocationManager.swift`
     - `DiskSpaceMonitor.swift`
     - `CleaningRulesEngine.swift`
     - `RuleEditorView.swift`
   - Ensure "Copy items if needed" is UNCHECKED
   - Ensure "Add to targets: HiddenBastard" is CHECKED
   - Click "Add"

4. **Verify all files**:
   - Select any `.swift` file in Project Navigator
   - Open File Inspector (⌘⌥1)
   - Check "Target Membership" → "HiddenBastard" should be checked

5. **Build**:
   - Press ⌘B or Product → Build
   - Should build successfully!

### Option 2: Command Line (Advanced)

If you prefer automation, you can use `xed` to open Xcode and manually verify:

```bash
cd /Users/greenplanet/Documents/hidden_bastard
open HiddenBastard.xcodeproj
```

Then follow GUI steps above.

---

## Expected File List

After setup, your Project Navigator should show:

```
HiddenBastard/
├── HiddenBastardApp.swift ✅
├── ContentView.swift ✅
├── Models.swift ✅
├── AppTheme.swift ✅
├── FileScanner.swift ✅
├── SettingsView.swift ✅
├── ScanLocationManager.swift ✅ NEW
├── DiskSpaceMonitor.swift ✅ NEW
├── CleaningRulesEngine.swift ✅ NEW
├── RuleEditorView.swift ✅ NEW
├── Info.plist ✅
├── HiddenBastard.entitlements ✅
└── ExportOptions.plist ✅
```

**REMOVED**: ~~Assets.swift~~ (was duplicate)

---

## Troubleshooting

### "Duplicate symbol" errors
- **Cause**: Assets.swift wasn't removed
- **Fix**: Remove Assets.swift reference from project

### "Cannot find X in scope"
- **Cause**: New files not added to target
- **Fix**: Select file, check "Target Membership" in File Inspector

### Build succeeds but crashes on launch
- **Cause**: Info.plist or entitlements misconfigured
- **Fix**: Verify Info.plist and entitlements match the versions in this repo

---

## Testing Checklist

After successful build:

1. ✅ Run app (⌘R)
2. ✅ Click "Add Folder" → Choose a folder (e.g., Downloads)
3. ✅ Click "Start Deep Scan"
4. ✅ View found files in "Files" tab
5. ✅ Create a new rule in "Rules" tab
6. ✅ Check disk usage in "Monitor" tab
7. ✅ Open Settings and verify links work

If all above work: **You're ready for App Store submission!**

---

## App Store Submission

Once Xcode build succeeds:

1. **Archive**:
   - Product → Archive
   - Wait for archive to complete

2. **Validate**:
   - Window → Organizer
   - Select latest archive
   - Click "Validate App"
   - Fix any issues reported

3. **Distribute**:
   - Click "Distribute App"
   - Choose "App Store Connect"
   - Follow prompts

4. **App Store Connect**:
   - Log in to https://appstoreconnect.apple.com
   - Create new app listing
   - Add metadata, screenshots, description
   - Submit for review

---

## Need Help?

- **Issues**: https://github.com/ghostintheprompt/hidden_bastard/issues
- **Xcode Help**: https://developer.apple.com/documentation/xcode
- **App Store Guidelines**: https://developer.apple.com/app-store/review/guidelines/

---

**Last Updated**: 2026-01-15
**Status**: Ready for Xcode project update
