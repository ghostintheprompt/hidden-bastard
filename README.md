# Hidden Bastard

**macOS Junk File Eliminator**

---

## macOS Hides Gigabytes of Junk

Your Mac says "Storage Almost Full." You delete files. Still full.

**Why:** macOS creates hidden files everywhere. Cache folders. System logs. Developer cruft. Spotlight indexes. Old iOS backups. Xcode derived data from projects you deleted years ago.

**Hidden files = gigabytes wasted.**

**Hidden Bastard finds them. Shows exactly what's consuming space. Lets you delete them.**

---

## What It Finds

### .DS_Store Files (Death By A Thousand Cuts)

macOS creates `.DS_Store` in every folder you open. Stores icon positions, view settings, folder metadata.

**The problem:** Thousands of these accumulate. Each is small (few KB). Together = megabytes.

**Worse:** They sync to cloud storage, external drives, network shares. Pollute everything.

**Hidden Bastard:** Finds all `.DS_Store` files. Shows total count + size. Deletes them system-wide.

### Cache Folders (The 20GB Surprise)

**Common cache hogs:**
- `~/Library/Caches/` (browser cache, app cache)
- Safari cache (multi-gigabyte easily)
- Chrome cache (even worse)
- Xcode derived data (10GB+ for developers)
- Spotify cache (downloads you forgot about)
- Slack cache (every image ever posted)

**Hidden Bastard:** Scans all cache locations. Shows size per app. Lets you clear selectively or nuke everything.

### iOS Backups (Ancient History)

iTunes/Finder creates local iPhone backups. Old ones never get deleted automatically.

**Common scenario:**
- Backed up iPhone 8 in 2019 (15GB backup)
- Got new phone in 2020
- Old backup still there
- Consuming space forever

**Hidden Bastard:** Lists all iOS backups with dates. Shows which devices. Delete ancient ones safely.

### Developer Cruft (If You Code)

**Xcode DerivedData:** 10-30GB for active developers. Contains build artifacts, module cache, logs.

**CocoaPods cache:** Old pod downloads that don't auto-delete.

**npm/node_modules:** Every project has full dependency tree. Gigabytes per project.

**Python venv:** Virtual environments that outlive their projects.

**Docker images:** Old containers consuming 20GB+.

**Hidden Bastard:** Targets developer-specific junk. Safely cleans build artifacts, cached dependencies, old environments.

### System Logs (The Silent Grower)

**System logs accumulate:**
- `/var/log/` (system logs)
- `~/Library/Logs/` (app logs)
- Diagnostic reports
- Crash logs from 2018

**Some logs hit gigabytes.** macOS doesn't aggressively rotate them.

**Hidden Bastard:** Identifies old logs safe to delete. Preserves recent ones (debugging). Clears ancient history.

### Trash That Won't Empty

**Sometimes Trash gets stuck:**
- Files "in use" (locked)
- Permission issues
- Corrupted items

**Trash shows empty. Still consuming gigabytes.**

**Hidden Bastard:** Force-empties Trash. Handles locked files. Actually frees the space.

---

## Installation

### Download App (Recommended)

1. Download from [Releases](https://github.com/ghostintheprompt/hidden-bastard/releases)
2. Drag to Applications
3. Launch
4. Grant Full Disk Access when prompted

### Build from Source

```bash
git clone https://github.com/ghostintheprompt/hidden-bastard
cd hidden-bastard
open HiddenBastard.xcodeproj
```

See [BUILD.md](BUILD.md) for detailed build instructions.

---

## System Requirements

- **macOS 13.0 (Ventura) or later**
- Full Disk Access permission (for system directories)
- Admin privileges for some operations

---

## Usage

1. **Launch Hidden Bastard**
2. **Click "Scan"** - scans system for junk files
3. **Review findings** - see exactly what's consuming space
4. **Select categories** - choose what to clean
5. **Click "Delete"** - confirm and free space
6. **Watch gigabytes vanish**

---

## What It Doesn't Delete

**Safe by default:**

**Won't touch:**
- User documents
- Photos/Music/Videos
- Application binaries
- System files (unless you force it)
- Active project files
- Recent caches (< 7 days by default)

**Only targets:**
- Hidden junk files
- Old caches
- Ancient backups
- Obsolete logs
- Developer build artifacts
- Trash contents

---

## Real-World Results

**Casual user:**
- .DS_Store: 5-15 MB
- Browser cache: 2-5 GB
- System logs: 500 MB - 1 GB
- **Total: ~3-7 GB freed**

**Developer:**
- Xcode DerivedData: 10-30 GB
- npm node_modules: 5-15 GB (all projects)
- Docker images: 10-20 GB
- Browser cache: 5 GB
- **Total: ~30-70 GB freed**

**Long-time Mac user (never cleaned):**
- iOS backups: 30-50 GB (multiple old devices)
- Cache folders: 20 GB
- System logs: 3-5 GB
- Developer cruft: 40 GB
- **Total: ~100+ GB freed**

---

## Why This Exists

**macOS has no built-in solution.**

**Storage Management UI is useless:**
- Shows large files (you already know about)
- Suggests deleting user documents
- Doesn't target hidden junk
- Forces manual hunting

**CleanMyMac costs $40/year:**
- Subscription model for basic cleanup
- Closed source (what is it actually doing?)
- Upsells constantly
- Over-engineered UI

**Hidden Bastard is free:**
- Open-source (verify the code)
- One-time install
- No subscriptions
- No telemetry
- No tracking
- Does one thing well

---

## Ghost Says...

Built this after "Storage Almost Full" warning on 512GB MacBook Pro. Deleted 100GB of user files. Still full.

Started investigating. Found:
- 18GB Xcode DerivedData (hadn't coded in months)
- 25GB iOS backups (iPhone 7 from 2017, iPhone X from 2019)
- 12GB browser cache
- 8GB system logs
- 3,000+ .DS_Store files polluting everything

**No built-in tool cleaned this.** CleanMyMac wanted $40/year subscription for basic functionality.

Built Hidden Bastard. Open-source. Multi-threaded scanning. Safe defaults. Actually shows what's consuming space before deleting.

**One scan freed 78GB.** Mac ran faster. No more storage warnings. Problem solved.

**If you're on Mac:** This tool finds junk you didn't know existed. Shows exactly what it is. Lets you reclaim gigabytes.

**If you're suspicious:** Read the code. It's open. No telemetry. No tracking. Just file system traversal and deletion.

Free. Open-source. Does what macOS should do automatically.

---

## Privacy & Security

All scanning happens locally on your machine. **No data is ever transmitted** outside of your computer.

No analytics. No tracking. No telemetry.

App is properly sandboxed and code-signed for security.

---

## License

MIT License - see [LICENSE](LICENSE) file

---

## Building & Distribution

See [BUILD.md](BUILD.md) for:
- Building in Xcode
- Code signing and notarization
- Creating distributable DMGs
- macOS compatibility details

---

**GitHub:** [github.com/ghostintheprompt/hidden-bastard](https://github.com/ghostintheprompt/hidden-bastard)

Your Mac. Your space. No junk.
