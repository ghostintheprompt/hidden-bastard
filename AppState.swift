import Foundation
import SwiftUI
import Combine

@MainActor
class AppState: ObservableObject {
    @Published var problemFiles: [ProblemFile] = []
    @Published var isScanning: Bool = false
    @Published var scanProgress: Float = 0.0
    @Published var scanStatus: String = ""
    @Published var scanLog: [String] = []
    
    // Services
    let scanner = FileScanner()
    let rulesEngine = RulesEngine()
    let diskMonitor = DiskSpaceMonitor()
    let locationManager = ScanLocationManager()
    
    // Selected files for deletion
    @Published var selectedFileIds: Set<UUID> = []
    
    var selectedFiles: [ProblemFile] {
        problemFiles.filter { selectedFileIds.contains($0.id) }
    }
    
    var totalSelectedSize: UInt64 {
        selectedFiles.reduce(0) { $0 + $1.size }
    }
    
    init() {
        // Initialize state if needed
    }
    
    func startScan() {
        isScanning = true
        scanProgress = 0
        problemFiles = []
        selectedFileIds = []

        Task { @MainActor in
            let locations = locationManager.scanLocations.filter { $0.isEnabled }
            let total = Float(max(locations.count, 1))
            var completed = 0
            var allFiles: [ProblemFile] = []
            scanLog = []

            scanLog.append("Starting scan of \(locations.count) location(s)...")

            for location in locations {
                guard !scanner.isCancelled else {
                    scanLog.append("Scan cancelled.")
                    break
                }
                scanStatus = "Scanning \(location.name)..."
                scanLog.append("→ \(location.path)")

                let files = await scanner.scan(locations: [location], locationManager: locationManager)
                allFiles.append(contentsOf: files)
                completed += 1
                scanProgress = Float(completed) / total
                scanLog.append("  Found \(files.count) item(s) in \(location.name)")
            }

            problemFiles = allFiles.sorted { $0.size > $1.size }
            isScanning = false
            let totalSize = ByteCountFormatter.string(fromByteCount: Int64(allFiles.reduce(0) { $0 + $1.size }), countStyle: .file)
            scanStatus = allFiles.isEmpty ? "Scan complete — nothing found above thresholds." : "Scan complete — \(allFiles.count) item(s) found, \(totalSize) recoverable."
            scanLog.append(scanStatus)
            selectedFileIds = Set(allFiles.filter { $0.riskLevel == .low }.map { $0.id })
        }
    }
    
    func cancelScan() {
        scanner.cancelScan()
        isScanning = false
        scanProgress = 0
    }
    
    func deleteSelectedFiles() {
        let filesToDelete = selectedFiles
        for file in filesToDelete {
            if scanner.deleteFile(path: file.path) {
                problemFiles.removeAll { $0.id == file.id }
                selectedFileIds.remove(file.id)
            }
        }
        diskMonitor.refresh()
    }
}

extension AppState: FileScannerDelegate {
    func scannerDidStartScan() {
        isScanning = true
    }
    
    func scannerDidUpdateProgress(progress: Float) {
        scanProgress = progress
    }
    
    func scannerDidFinishScan(files: [ProblemFile]) {
        problemFiles = files
        isScanning = false
        // Auto-select files with low risk
        selectedFileIds = Set(files.filter { $0.riskLevel == .low }.map { $0.id })
    }
}
