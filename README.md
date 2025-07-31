# Hidden Bastard File Deleter

## The Hidden File Problem

Are you sick of those crooked motherfuckers at Apple hiding files all over your Mac? So are we.

Every day, your Mac silently accumulates GIGABYTES of hidden files you never asked for:
- "Application support" that's just bloated crap
- "Containers" filled with useless temporary files
- "Caches" that never get cleared automatically
- "Analysis" data that tracks your media usage

**WHY THE HELL ARE THESE FILES HIDDEN?** Because they don't want you to know how much space they're wasting.

## Reclaim Your Disk Space

Hidden Bastard File Deleter exposes these secret storage hogs and gives YOU back control of YOUR computer. This powerful macOS application is designed by people who are TIRED of Apple's hidden file bullshit.

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

## No Permission Bullshit

Unlike Apple's own "storage management" that shows you nothing useful, we actually show you what's eating your space and let you nuke it all. Our app requires Full Disk Access because we don't play by Apple's hide-and-seek rules.

## System Requirements

- macOS 11.0 (Big Sur) or later
- Admin privileges for certain cleaning operations

## Installation

1. Download the latest release from the [Releases](https://github.com/MdrnDme/hidden-bastard-file-eliminator/releases) page
2. Drag the app to your Applications folder
3. Grant Full Disk Access when prompted (essential for finding what those motherfuckers are hiding)

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

We respect YOUR privacy, unlike some companies. All scanning happens locally on your machine. No data is ever transmitted outside of your computer.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
