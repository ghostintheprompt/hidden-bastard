import Foundation

// The main file scanning engine
class FileScanner {
    // Delegate to report progress and findings
    var delegate: FileScannerDelegate?

    // Scan progress
    private(set) var isScanning = false
    private var shouldCancel = false

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

    // Start scanning user-selected locations
    func startScan(locations: [ScanLocation], locationManager: ScanLocationManager) {
        guard !isScanning else { return }

        isScanning = true
        shouldCancel = false

        // Run on background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            // Filter to enabled locations only
            let enabledLocations = locations.filter { $0.isEnabled }

            if let delegate = self.delegate {
                Task { @MainActor in
                    delegate.scannerDidStartScan()
                }
            }

            var problemFiles: [ProblemFile] = []

            // Process each location
            for (index, location) in enabledLocations.enumerated() {
                // Check for cancellation
                if self.shouldCancel {
                    break
                }

                let progress = Float(index) / Float(max(enabledLocations.count, 1))
                if let delegate = self.delegate {
                    Task { @MainActor in
                        delegate.scannerDidUpdateProgress(progress: progress)
                    }
                }

                // Resolve bookmark to get access
                guard let url = locationManager.resolveBookmark(for: location) else {
                    continue
                }

                // Start accessing security-scoped resource
                let accessing = url.startAccessingSecurityScopedResource()
                defer {
                    if accessing {
                        url.stopAccessingSecurityScopedResource()
                    }
                }

                // Determine the primary category for this location
                let primaryCategory = location.categories.first ?? "Other"

                // Get threshold for this category
                let sizeThreshold = self.categorySizeThresholds[primaryCategory] ?? 10_000_000

                // Get pattern for this category (if any)
                let pattern = self.categoryPatterns[primaryCategory]

                // Determine risk level based on category
                let riskLevel = self.riskLevelForCategory(primaryCategory)

                // Scan the directory
                let files = self.scanDirectory(
                    path: url.path,
                    recursive: true,
                    sizeThreshold: sizeThreshold,
                    pattern: pattern,
                    category: primaryCategory,
                    riskLevel: riskLevel
                )

                problemFiles.append(contentsOf: files)
            }

            // Post results on main thread
            DispatchQueue.main.async {
                self.isScanning = false
                self.delegate?.scannerDidFinishScan(files: problemFiles)
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
    func deleteFile(path: String) -> Bool {
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