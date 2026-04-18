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
        "Incomplete Downloads": 10_000_000,      // 10MB
        "Application Caches": 100_000_000,       // 100MB
        "Developer Files": 500_000_000,          // 500MB
        "System Logs": 50_000_000,               // 50MB
        "Docker": 1_000_000_000,                 // 1GB
        "Trash Items": 100_000_000               // 100MB
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
        
        isScanning = false
        return allResults
    }

    private func scanLocation(_ location: ScanLocation, locationManager: ScanLocationManager) async -> [ProblemFile] {
        guard let url = locationManager.resolveBookmark(for: location) else {
            return []
        }

        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let primaryCategory = location.categories.first ?? "Other"
        let sizeThreshold = self.categorySizeThresholds[primaryCategory] ?? 10_000_000
        let pattern = self.categoryPatterns[primaryCategory]
        let riskLevel = self.riskLevelForCategory(primaryCategory)

        return await withCheckedContinuation { continuation in
            let results = self.scanDirectory(
                path: url.path,
                recursive: true,
                sizeThreshold: sizeThreshold,
                pattern: pattern,
                category: primaryCategory,
                riskLevel: riskLevel
            )
            continuation.resume(returning: results)
        }
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
    
    // Returns the size of a directory
    private func getDirectorySize(path: String) -> UInt64 {
        var totalSize: UInt64 = 0
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: path)
            
            for filename in contents {
                let filePath = URL(fileURLWithPath: path).appendingPathComponent(filename).path
                var isDirectory: ObjCBool = false
                
                if FileManager.default.fileExists(atPath: filePath, isDirectory: &isDirectory) {
                    if isDirectory.boolValue {
                        // Recursively get subdirectory size
                        totalSize += getDirectorySize(path: filePath)
                    } else {
                        // Get file size
                        do {
                            let attributes = try FileManager.default.attributesOfItem(atPath: filePath)
                            if let size = attributes[.size] as? UInt64 {
                                totalSize += size
                            }
                        } catch {
                            print("Error getting size for \(filePath): \(error)")
                        }
                    }
                }
            }
        } catch {
            print("Error reading directory \(path): \(error)")
        }
        
        return totalSize
    }
    
    // Cancel an ongoing scan
    func cancelScan() {
        shouldCancel = true
    }

    // Delete a file or directory
    func deleteFile(path: String, isSimulation: Bool = false) -> Bool {
        if isSimulation {
            print("[Simulation] Would delete: \(path)")
            return true
        }
        
        do {
            try FileManager.default.removeItem(atPath: path)
            return true
        } catch {
            print("Error deleting \(path): \(error)")
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