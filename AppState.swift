import Foundation
import SwiftUI
import Combine

@MainActor
class AppState: ObservableObject {
    @Published var problemFiles: [ProblemFile] = []
    @Published var isScanning: Bool = false
    @Published var scanProgress: Float = 0.0
    
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
        
        Task {
            // This will be updated to use the new async FileScanner
            scanner.delegate = self
            scanner.startScan(locations: locationManager.scanLocations, locationManager: locationManager)
        }
    }
    
    func cancelScan() {
        scanner.cancelScan()
        isScanning = false
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
