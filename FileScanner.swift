import Foundation

// The main file scanning engine
class FileScanner {
    // Delegate to report progress and findings
    weak var delegate: FileScannerDelegate?
    
    // Scan progress
    private(set) var isScanning = false
    private var shouldCancel = false
    
    // Categories to scan
    let knownProblemPaths: [String: [FileScanRule]] = [
        "Apple Media Analysis": [
            FileScanRule(
                path: "/Library/Containers/com.apple.mediaanalysisd",
                recursive: true,
                sizeThreshold: 100_000_000, // 100MB
                pattern: nil,
                description: "Apple's media analysis cache and models",
                riskLevel: .medium
            )
        ],
        "Incomplete Downloads": [
            FileScanRule(
                path: "~/Downloads",
                recursive: true,
                sizeThreshold: 10_000_000, // 10MB
                pattern: "\\.part$|\\.download$|\\.crdownload$|\\.unconfirmed$|\\.downloading$",
                description: "Partial download files",
                riskLevel: .low
            ),
            FileScanRule(
                path: "~/Desktop",
                recursive: true,
                sizeThreshold: 10_000_000, // 10MB
                pattern: "\\.part$|\\.download$|\\.crdownload$|\\.unconfirmed$|\\.downloading$",
                description: "Partial download files",
                riskLevel: .low
            )
        ],
        "Application Caches": [
            FileScanRule(
                path: "~/Library/Caches",
                recursive: true,
                sizeThreshold: 500_000_000, // 500MB
                pattern: nil,
                description: "Application cache files",
                riskLevel: .low
            )
        ],
        "Developer Files": [
            FileScanRule(
                path: "~/Library/Developer/Xcode/DerivedData",
                recursive: true,
                sizeThreshold: 1_000_000_000, // 1GB
                pattern: nil,
                description: "Xcode temporary build files",
                riskLevel: .low
            ),
            FileScanRule(
                path: "~/Library/Developer/CoreSimulator/Devices",
                recursive: true,
                sizeThreshold: 2_000_000_000, // 2GB
                pattern: nil,
                description: "iOS simulator files",
                riskLevel: .medium
            )
        ],
        "System Logs": [
            FileScanRule(
                path: "/var/log",
                recursive: true,
                sizeThreshold: 100_000_000, // 100MB
                pattern: nil,
                description: "System logs",
                riskLevel: .medium
            ),
            FileScanRule(
                path: "~/Library/Logs",
                recursive: true,
                sizeThreshold: 100_000_000, // 100MB
                pattern: nil,
                description: "User application logs",
                riskLevel: .low
            )
        ],
        "Docker": [
            FileScanRule(
                path: "~/Library/Containers/com.docker.docker/Data",
                recursive: true,
                sizeThreshold: 5_000_000_000, // 5GB
                pattern: nil,
                description: "Docker images and containers",
                riskLevel: .medium
            )
        ],
        "Trash Items": [
            FileScanRule(
                path: "~/.Trash",
                recursive: true,
                sizeThreshold: 1_000_000_000, // 1GB
                pattern: nil,
                description: "Files in Trash",
                riskLevel: .low
            )
        ]
    ]
    
    // Start scanning for the selected categories
    func startScan(categories: [String]) {
        guard !isScanning else { return }
        
        isScanning = true
        shouldCancel = false
        
        // Run on background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Get rules for selected categories
            let rulesToScan = categories.flatMap { category in
                return self.knownProblemPaths[category] ?? []
            }
            
            self.delegate?.scannerDidStartScan()
            
            var problemFiles: [ProblemFile] = []
            
            // Process each rule
            for (index, rule) in rulesToScan.enumerated() {
                // Check for cancellation
                if self.shouldCancel {
                    break
                }
                
                let progress = Float(index) / Float(rulesToScan.count)
                self.delegate?.scannerDidUpdateProgress(progress: progress)
                
                // Expand path if needed
                let expandedPath = NSString(string: rule.path).standardizingPath
                
                // Check if path exists
                var isDirectory: ObjCBool = false
                if FileManager.default.fileExists(atPath: expandedPath, isDirectory: &isDirectory) {
                    if isDirectory.boolValue {
                        // Scan directory
                        let files = self.scanDirectory(
                            path: expandedPath,
                            recursive: rule.recursive,
                            sizeThreshold: rule.sizeThreshold,
                            pattern: rule.pattern,
                            category: self.categoryForRule(rule),
                            riskLevel: rule.riskLevel
                        )
                        problemFiles.append(contentsOf: files)
                    } else {
                        // Single file check
                        do {
                            let attributes = try FileManager.default.attributesOfItem(atPath: expandedPath)
                            if let size = attributes[.size] as? UInt64, size > rule.sizeThreshold {
                                let file = ProblemFile(
                                    name: URL(fileURLWithPath: expandedPath).lastPathComponent,
                                    path: expandedPath,
                                    size: size,
                                    dateModified: attributes[.modificationDate] as? Date ?? Date(),
                                    category: self.categoryForRule(rule),
                                    riskLevel: rule.riskLevel
                                )
                                problemFiles.append(file)
                            }
                        } catch {
                            print("Error reading attributes: \(error)")
                        }
                    }
                }
            }
            
            // Post results on main thread
            DispatchQueue.main.async {
                self.isScanning = false
                self.delegate?.scannerDidFinishScan(files: problemFiles)
            }
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
    
    // Determine which category a rule belongs to
    private func categoryForRule(_ rule: FileScanRule) -> String {
        for (category, rules) in knownProblemPaths {
            if rules.contains(where: { $0.path == rule.path }) {
                return category
            }
        }
        return "Other"
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
protocol FileScannerDelegate: AnyObject {
    func scannerDidStartScan()
    func scannerDidUpdateProgress(progress: Float)
    func scannerDidFinishScan(files: [ProblemFile])
}

// Rule for file scanning
struct FileScanRule {
    let path: String
    let recursive: Bool
    let sizeThreshold: UInt64
    let pattern: String?
    let description: String
    let riskLevel: RiskLevel
}

// Root helper for accessing protected files
class RootHelper {
    static func executeWithPrivileges(command: String, completion: @escaping (Bool) -> Void) {
        // In a real app, this would use AuthorizationExecuteWithPrivileges or a helper tool
        // For now, we'll just simulate success
        print("Executing privileged command: \(command)")
        completion(true)
    }
}