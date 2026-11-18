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
        "Large Downloads": 250_000_000,          // 250MB
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
        let excludedPaths = await locationManager.exclusionsSnapshot()
        var allResults: [ProblemFile] = []
        
        await withTaskGroup(of: [ProblemFile].self) { group in
            for location in enabledLocations {
                group.addTask {
                    return await self.scanLocation(location, locationManager: locationManager, excludedPaths: excludedPaths)
                }
            }
            
            for await results in group {
                allResults.append(contentsOf: results)
            }
        }

        isScanning = false
        return allResults
    }

    /// Finds large immediate subfolders in broad, review-only areas outside the
    /// normal cleanup allow-list. These results are never auto-selected.
    func scanUnlistedLargeFolders(
        roots: [String],
        coveredPaths: [String],
        excludedPaths: [String],
        minSize: UInt64 = 500_000_000
    ) async -> [ProblemFile] {
        var results: [ProblemFile] = []
        var seenPaths = Set<String>()
        let fm = FileManager.default

        for root in roots {
            if shouldCancel { break }
            guard fm.fileExists(atPath: root),
                  !excludedPaths.contains(where: { isDescendant(root, of: $0) }) else { continue }

            func appendCandidate(_ path: String, size: UInt64) {
                guard !path.isEmpty, path != root,
                      !seenPaths.contains(path),
                      !coveredPaths.contains(where: { pathsOverlap(path, $0) }),
                      !excludedPaths.contains(where: { pathsOverlap(path, $0) }),
                      !roots.contains(where: { $0 != root && isDescendant($0, of: path) }),
                      size >= minSize else { return }
                guard let attributes = try? fm.attributesOfItem(atPath: path),
                      let modified = attributes[.modificationDate] as? Date else {
                    print("Could not read modification date for \(path).")
                    return
                }
                seenPaths.insert(path)
                let name = (path as NSString).lastPathComponent
                results.append(ProblemFile(name: name, path: path, size: size,
                                           dateModified: modified, category: "Large App Data", riskLevel: .high))
            }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/du")
            process.arguments = ["-k", "-d", "1", root]
            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = FileHandle.nullDevice

            do {
                try process.run()
            } catch {
                print("Failed to scan large folders under \(root): \(error.localizedDescription)")
                continue
            }

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            if process.terminationStatus != 0 {
                print("Could not fully scan large folders under \(root) (du exit \(process.terminationStatus)).")
            }

            guard let output = String(data: outputData, encoding: .utf8) else {
                print("Could not decode large-folder scan output under \(root).")
                continue
            }
            for line in output.components(separatedBy: "\n") {
                if shouldCancel { break }
                let parts = line.components(separatedBy: "\t")
                guard parts.count == 2,
                      let kb = UInt64(parts[0].trimmingCharacters(in: .whitespaces)) else { continue }
                let path = parts[1].trimmingCharacters(in: .whitespaces)
                let (size, overflow) = kb.multipliedReportingOverflow(by: 1024)
                guard !overflow else { continue }
                appendCandidate(path, size: size)
            }

            do {
                for name in try fm.contentsOfDirectory(atPath: root) {
                    if shouldCancel { break }
                    let path = (root as NSString).appendingPathComponent(name)
                    guard let attributes = try? fm.attributesOfItem(atPath: path),
                          let type = attributes[.type] as? FileAttributeType,
                          type == .typeRegular,
                          let fileSize = attributes[.size] as? NSNumber else { continue }
                    appendCandidate(path, size: fileSize.uint64Value)
                }
            } catch {
                print("Could not list immediate files under \(root): \(error.localizedDescription)")
            }
        }

        return results
    }

    private func pathsOverlap(_ first: String, _ second: String) -> Bool {
        isDescendant(first, of: second) || isDescendant(second, of: first)
    }

    private func isDescendant(_ path: String, of root: String) -> Bool {
        let normalizedRoot = root.hasSuffix("/") ? String(root.dropLast()) : root
        return path == normalizedRoot || path.hasPrefix(normalizedRoot + "/")
    }

    private func scanLocation(
        _ location: ScanLocation,
        locationManager: ScanLocationManager,
        excludedPaths: [String]
    ) async -> [ProblemFile] {
        guard let url = locationManager.resolveBookmark(for: location) else { return [] }

        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        let category = location.categories.first ?? "Other"
        let sizeThreshold = self.categorySizeThresholds[category] ?? 1_000_000
        let riskLevel = self.riskLevelForCategory(category)
        let path = url.path
        guard !excludedPaths.contains(where: { self.isDescendant(path, of: $0) }) else { return [] }

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
                if excludedPaths.contains(where: { self.pathsOverlap(childPath, $0) }) { continue }
                let name = (childPath as NSString).lastPathComponent
                var resultCategory = category
                var resultRisk = riskLevel
                var resultThreshold = sizeThreshold
                if category == "Incomplete Downloads" {
                    if let pattern = self.categoryPatterns[category],
                       name.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
                        resultThreshold = self.categorySizeThresholds["Incomplete Downloads"] ?? sizeThreshold
                    } else {
                        resultCategory = "Large Downloads"
                        resultRisk = .high
                        resultThreshold = self.categorySizeThresholds["Large Downloads"] ?? sizeThreshold
                    }
                }
                guard size >= resultThreshold else { continue }
                guard let attributes = try? fm.attributesOfItem(atPath: childPath),
                      let modified = attributes[.modificationDate] as? Date else {
                    print("Could not read modification date for \(childPath).")
                    continue
                }
                results.append(ProblemFile(name: name, path: childPath, size: size, dateModified: modified, category: resultCategory, riskLevel: resultRisk))
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
        case "Large Downloads":
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