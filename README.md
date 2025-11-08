# Hidden Bastard File Deleter

<p align="center">
  <img src="docs/app-icon-placeholder.png" width="128" height="128" alt="Hidden Bastard App Icon">
</p>

<p align="center">
  <strong>Reclaim Your Disk Space with Confidence</strong>
</p>

## The Hidden File Problem

Your Mac silently accumulates GIGABYTES of hidden files you never asked for:
- Application support files that grow without limit
- Container directories filled with temporary files
- Caches that are never automatically cleared
- Media analysis data consuming tens of gigabytes
- Developer artifacts from Xcode and simulators

**These files are hidden by design** - but they're wasting your valuable storage space.

## Take Back Control

Hidden Bastard reveals these hidden storage hogs and gives you back control of your computer. This powerful macOS application helps you identify and safely remove files that are wasting your disk space.

## Technical Features

- **Advanced File System Traversal**: Scans typically restricted directories using elevated privileges
- **Pattern-Based Detection**: Uses regex matching to identify problematic file patterns
- **Multi-threaded Scanning**: Processes your filesystem with parallel execution paths for maximum efficiency
- **Metadata Analysis**: Examines file metadata to identify abandoned temporary files
- **Incremental Database**: Tracks changes between scans to quickly identify new storage abusers

## What We Target

- **Apple Media Analysis (~20GB)**: Large neural network models and media processing caches
- **Incomplete Downloads (~5GB)**: Partial downloads abandoned by browsers and apps
- **Application Caches (~15GB)**: "Temporary" files that mysteriously become permanent
- **Developer Files (~50GB+)**: Xcode and other dev tools leave behind massive build artifacts
- **System Logs (~10GB)**: Endless logs no human will ever read
- **Docker Bloat (~30GB+)**: Unused images, containers, and volumes
- **iCloud Cached Files (~25GB+)**: Local copies of "cloud" files you thought were saving space

## Transparent & Powerful

Unlike macOS's built-in storage management that provides limited information, Hidden Bastard shows you exactly what's consuming your space and lets you decide what to keep or delete. The app requests Full Disk Access to scan system-protected directories and provide complete visibility.

## System Requirements

- macOS 11.0 (Big Sur) or later
- Admin privileges for certain cleaning operations

## Installation

### Option 1: Download DMG (Recommended)

1. Download the latest release from the [Releases](https://github.com/ghostintheprompt/hidden_bastard/releases) page
2. Open the DMG and drag Hidden Bastard to your Applications folder
3. Launch the app
4. Grant Full Disk Access when prompted (System Preferences → Security & Privacy → Privacy → Full Disk Access)

### Option 2: Build from Source

See [BUILD.md](BUILD.md) for detailed build instructions.

```bash
git clone https://github.com/ghostintheprompt/hidden_bastard.git
cd hidden_bastard
open HiddenBastard.xcodeproj
```

## The Technical Details

Hidden Bastard uses a sophisticated multi-tiered scanning architecture:

```
FileScanner → DirectoryTraversal → FileAnalyzer → MetadataExtractor → SizeCalculator → ReportGenerator
```

Our proprietary risk assessment algorithm evaluates each file based on:
- Last access timestamp
- Process association history
- System criticality index
- Content fingerprinting

## Privacy & Security

Your privacy is paramount. All scanning happens locally on your machine. **No data is ever transmitted** outside of your computer. No analytics, no tracking, no telemetry.

The app is properly sandboxed and code-signed for your security.

## Licensing

Hidden Bastard is distributed as shareware:

- **Trial Version**: Full scanning capabilities, 10GB deletion limit per session
- **Licensed Version**: $19.99 - Unlimited deletions, automated cleaning rules, priority support

Purchase a license to unlock all features and support continued development.

## Screenshots

<p align="center">
  <img src="docs/screenshot-scan.png" width="600" alt="Scan View">
  <br>
  <em>Intuitive scan interface with category selection</em>
</p>

<p align="center">
  <img src="docs/screenshot-results.png" width="600" alt="Results View">
  <br>
  <em>Detailed file list with size and risk analysis</em>
</p>

## Building & Distribution

See [BUILD.md](BUILD.md) for comprehensive instructions on:
- Building the app in Xcode
- Code signing and notarization
- Creating distributable DMGs
- Integrating payment systems for shareware licensing
- Marketing and distribution strategies

## License

This project is licensed under the MIT License - see the LICENSE file for details.
