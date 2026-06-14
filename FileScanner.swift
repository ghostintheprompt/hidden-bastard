import Foundation

// The main file scanning engine
class FileScanner {
    // Delegate to report progress and findings (Legacy, for backward compatibility)
    var delegate: FileScannerDelegate?

    // Scan progress
    private(set) var isScanning = false
    private var shouldCancel = false
    var isCancelled: Bool { shouldCancel }

    // Pattern-based rules for categorizing files
    private let categoryPatterns: [String: String] = [
        "Incomplete Downloads": "\\.part$|\\.download$|\\.crdownload$|\\.unconfirmed$|\\.downloading$",
        "Developer Files": "DerivedData|CoreSimulator|node_modules|__pycache__",
        "System Logs": "\\.log$|\\.log\\.[0-9]+$",
        "Docker": "docker/containers|docker/volumes"
    ]

    private let categorySizeThresholds: [String: UInt64] = [
        "Incomplete Downloads": 1_000_000,       // 1MB
        "Application Caches": 5_000_000,         // 5MB
        "Developer Files": 50_000_000,           // 50MB
        "System Logs": 1_000_000,                // 1MB
        "Docker": 100_000_000,                   // 100MB
        "Trash Items": 1_000_000,                // 1MB
        "Large App Data": 250_000_000            // 250MB — only surface genuinely big folders
    ]

    // MARK: - Modern Async API

    /// Scans multiple locations in parallel using TaskGroups
    func scan(locations: [ScanLocation], locationManager: ScanLocationManager, isSimulation: Bool = false) async -> [ProblemFile] {
        isScanning = true
        shouldCancel = false
        
        let enabledLocations = locations.filter { $0.isEnabled }
        var allResults: [ProblemFile] = []
        
        await withTaskGroup(of: [ProblemFile].self) { group in
            for location in enabledLocations {
                group.addTask {
                    return await self.scanLocation(location, locationManager: locationManager)
                }
            }
            
            for await results in group {
                allResults.append(contentsOf: results)
            }
        }

        // Deep "biggest folders" pass — finds large folders under ~/Library
        // regardless of the allow-list above, so space-hogs nothing knows about
        // (a 4 GB browser AI model, 19 GB of simulators, etc.) still surface.
        if !shouldCancel {
            let homeLib = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library").path
            let deep = self.scanBiggestFolders(roots: [homeLib], maxDepth: 4, minSize: 500_000_000)
            let known = Set(allResults.map { $0.path })
            for f in deep where !known.contains(f.path) {
                allResults.append(f)
            }
        }

        isScanning = false
        return allResults
    }

    // MARK: - Deep "biggest folders" scan

    /// Walks each root to `maxDepth` and returns the largest folders above `minSize`,
    /// classified by how safe they are to delete. Unlike the allow-list scan, this
    /// surfaces big folders no one hardcoded — the real fix for "it missed everything."
    func scanBiggestFolders(roots: [String], maxDepth: Int = 4, minSize: UInt64 = 500_000_000) -> [ProblemFile] {
        var raw: [(path: String, size: UInt64)] = []
        for root in roots {
            let escaped = root.replacingOccurrences(of: "'", with: "'\\''")
            let shell = Process()
            shell.executableURL = URL(fileURLWithPath: "/bin/sh")
            // du -k -d N gives cumulative sizes of every folder down to depth N.
            shell.arguments = ["-c", "du -k -d \(maxDepth) '\(escaped)' 2>/dev/null"]
            let pipe = Pipe()
            shell.standardOutput = pipe
            shell.standardError = Pipe()
            try? shell.run()
            shell.waitUntilExit()
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            for line in output.components(separatedBy: "\n") {
                if shouldCancel { break }
                let parts = line.components(separatedBy: "\t")
                guard parts.count == 2,
                      let kb = UInt64(parts[0].trimmingCharacters(in: .whitespaces)) else { continue }
                let path = parts[1].trimmingCharacters(in: .whitespaces)
                guard !path.isEmpty, path != root else { continue }   // skip the root aggregate itself
                let size = kb * 1024
                guard size >= minSize else { continue }
                raw.append((path, size))
            }
        }

        // De-duplicate the tree: drop an ancestor folder when a descendant we're
        // already keeping accounts for ~80%+ of it, so we surface the specific hog
        // (…/CoreSimulator/Devices) instead of the aggregate (…/Library/Developer).
        let bySize = raw.sorted { $0.size > $1.size }
        var kept: [(path: String, size: UInt64)] = []
        for item in bySize {
            let dominatedByChild = kept.contains {
                $0.path.hasPrefix(item.path + "/") && $0.size >= UInt64(Double(item.size) * 0.8)
            }
            if dominatedByChild { continue }
            kept.append(item)
        }

        let fm = FileManager.default
        return kept.sorted { $0.size > $1.size }.prefix(80).map { item in
            let (category, risk) = classifyBigFolder(path: item.path)
            let modified = (try? fm.attributesOfItem(atPath: item.path)[.modificationDate] as? Date) ?? Date()
            let name = (item.path as NSString).lastPathComponent
            return ProblemFile(name: name, path: item.path, size: item.size,
                               dateModified: modified, category: category, riskLevel: risk)
        }
    }

    /// Best-effort safety classification of a big folder by known path signatures.
    private func classifyBigFolder(path: String) -> (String, RiskLevel) {
        let p = path.lowercased()
        // Regenerable build artifacts / dev data → safe-ish (medium)
        let devSignatures = ["coresimulator/devices", "coresimulator/caches", "deriveddata",
                             "node_modules", "devicesupport", "/.gradle/", "/.pub-cache",
                             "ios devicesupport", "archives"]
        for sig in devSignatures where p.contains(sig) { return ("Developer Files", .medium) }
        // Pure caches → safe (low)
        let cacheSignatures = ["/caches/", "/cache/", "gpucache", "code cache", "service worker",
                               "shadercache", "grshadercache", "optguideondevicemodel",
                               "optguideondeviceclassifiermodel", "/cacheddata", "/diagnosticreports"]
        for sig in cacheSignatures where p.contains(sig) { return ("Application Caches", .low) }
        // Big and unfamiliar → may hold real data, review first
        return ("Large App Data", .high)
    }

    private func scanLocation(_ location: ScanLocation, locationManager: ScanLocationManager) async -> [ProblemFile] {
        guard let url = locationManager.resolveBookmark(for: location) else { return [] }

        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        let category = location.categories.first ?? "Other"
        let sizeThreshold = self.categorySizeThresholds[category] ?? 1_000_000
        let riskLevel = self.riskLevelForCategory(category)
        let path = url.path

        return await withCheckedContinuation { continuation in
            // One du call to get sizes of all children at once
            let sizes = self.duSizes(in: path)
            guard !sizes.isEmpty else {
                continuation.resume(returning: [])
                return
            }

            var results: [ProblemFile] = []
            let fm = FileManager.default

            for (childPath, size) in sizes {
                if self.shouldCancel { break }
                let name = (childPath as NSString).lastPathComponent
                guard size >= sizeThreshold else { continue }
                let modified = (try? fm.attributesOfItem(atPath: childPath)[.modificationDate] as? Date) ?? Date()
                results.append(ProblemFile(name: name, path: childPath, size: size, dateModified: modified, category: category, riskLevel: riskLevel))
            }
            continuation.resume(returning: results)
        }
    }

    // Run du -sk on all children (including hidden) in one shell call
    private func duSizes(in directoryPath: String) -> [(String, UInt64)] {
        let escaped = directoryPath.replacingOccurrences(of: "'", with: "'\\''")
        let shell = Process()
        shell.executableURL = URL(fileURLWithPath: "/bin/sh")
        // Include hidden files via .[!.]* glob alongside regular *
        shell.arguments = ["-c", "du -sk '\(escaped)'/* '\(escaped)'/.[!.]* 2>/dev/null | sort -rn"]
        let pipe = Pipe()
        shell.standardOutput = pipe
        shell.standardError = Pipe()
        try? shell.run()
        shell.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        var results: [(String, UInt64)] = []
        for line in output.components(separatedBy: "\n") {
            let parts = line.components(separatedBy: "\t")
            guard parts.count == 2,
                  let kb = UInt64(parts[0].trimmingCharacters(in: .whitespaces)) else { continue }
            let childPath = parts[1].trimmingCharacters(in: .whitespaces)
            guard !childPath.isEmpty else { continue }
            results.append((childPath, kb * 1024))
        }
        return results
    }

    // MARK: - Legacy Delegate API

    // Start scanning user-selected locations
    func startScan(locations: [ScanLocation], locationManager: ScanLocationManager) {
        guard !isScanning else { return }

        Task {
            let files = await scan(locations: locations, locationManager: locationManager)
            await MainActor.run {
                self.delegate?.scannerDidFinishScan(files: files)
            }
        }
    }

    // Determine risk level based on category
    private func riskLevelForCategory(_ category: String) -> RiskLevel {
        switch category {
        case "System Logs", "Docker":
            return .medium
        case "Developer Files":
            return .medium
        case "Trash Items":
            return .low
        case "Large App Data":
            return .high
        default:
            return .low
        }
    }
    
    // Recursively scans a directory for files matching the criteria
    private func scanDirectory(
        path: String,
        recursive: Bool,
        sizeThreshold: UInt64,
        pattern: String?,
        category: String,
        riskLevel: RiskLevel
    ) -> [ProblemFile] {
        var results: [ProblemFile] = []
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: URL(fileURLWithPath: path),
                includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]
            )
            
            for fileURL in contents {
                if shouldCancel {
                    return results
                }
                
                let filePath = fileURL.path
                
                // Skip if it doesn't match pattern
                if let pattern = pattern, let regex = try? NSRegularExpression(pattern: pattern) {
                    let filename = fileURL.lastPathComponent
                    let range = NSRange(location: 0, length: filename.utf16.count)
                    if regex.firstMatch(in: filename, range: range) == nil {
                        // Skip if doesn't match pattern
                        if recursive {
                            var isDirectory: ObjCBool = false
                            if FileManager.default.fileExists(atPath: filePath, isDirectory: &isDirectory), isDirectory.boolValue {
                                // Recursively scan subdirectories
                                let subResults = scanDirectory(
                                    path: filePath,
                                    recursive: true,
                                    sizeThreshold: sizeThreshold,
                                    pattern: pattern,
                                    category: category,
                                    riskLevel: riskLevel
                                )
                                results.append(contentsOf: subResults)
                            }
                        }
                        continue
                    }
                }
                
                do {
                    var isDirectory: ObjCBool = false
                    if FileManager.default.fileExists(atPath: filePath, isDirectory: &isDirectory) {
                        if isDirectory.boolValue {
                            if recursive {
                                // Recursively scan subdirectories
                                let subResults = scanDirectory(
                                    path: filePath,
                                    recursive: true,
                                    sizeThreshold: sizeThreshold,
                                    pattern: pattern,
                                    category: category,
                                    riskLevel: riskLevel
                                )
                                results.append(contentsOf: subResults)
                                
                                // If we're checking directories as well, calculate directory size
                                let directorySize = getDirectorySize(path: filePath)
                                if directorySize > sizeThreshold {
                                    // Only add directory if it's above threshold
                                    let file = ProblemFile(
                                        name: fileURL.lastPathComponent,
                                        path: filePath,
                                        size: directorySize,
                                        dateModified: try fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? Date(),
                                        category: category,
                                        riskLevel: riskLevel
                                    )
                                    results.append(file)
                                }
                            }
                        } else {
                            // Check file size
                            let attributes = try FileManager.default.attributesOfItem(atPath: filePath)
                            if let size = attributes[.size] as? UInt64, size > sizeThreshold {
                                let file = ProblemFile(
                                    name: fileURL.lastPathComponent,
                                    path: filePath,
                                    size: size,
                                    dateModified: attributes[.modificationDate] as? Date ?? Date(),
                                    category: category,
                                    riskLevel: riskLevel
                                )
                                results.append(file)
                            }
                        }
                    }
                } catch {
                    print("Error accessing \(filePath): \(error)")
                }
            }
        } catch {
            print("Error reading directory \(path): \(error)")
        }
        
        return results
    }
    
    // Returns the size of a directory using du for speed
    private func getDirectorySize(path: String) -> UInt64 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/du")
        process.arguments = ["-sk", path]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        try? process.run()
        process.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        if let sizeStr = output.components(separatedBy: "\t").first,
           let kb = UInt64(sizeStr.trimmingCharacters(in: .whitespaces)) {
            return kb * 1024
        }
        return 0
    }
    
    // Cancel an ongoing scan
    func cancelScan() {
        shouldCancel = true
    }

    // Move to Trash (safer than permanent delete)
    func deleteFile(path: String, isSimulation: Bool = false) -> Bool {
        if isSimulation { return true }
        if !FileManager.default.fileExists(atPath: path) { return true }
        do {
            try FileManager.default.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: nil)
            return true
        } catch {
            print("Trash failed for \(path): \(error.localizedDescription)")
            return false
        }
    }
}

// Protocol for reporting scan progress
@MainActor
protocol FileScannerDelegate: Sendable {
    func scannerDidStartScan()
    func scannerDidUpdateProgress(progress: Float)
    func scannerDidFinishScan(files: [ProblemFile])
}