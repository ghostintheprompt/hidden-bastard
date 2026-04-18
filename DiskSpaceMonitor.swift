import Foundation
import SwiftUI
import UserNotifications

// Monitors disk space usage and provides real-time statistics
@MainActor
class DiskSpaceMonitor: ObservableObject {
    @Published var totalSpace: UInt64 = 0
    @Published var usedSpace: UInt64 = 0
    @Published var freeSpace: UInt64 = 0
    @Published var usagePercentage: Double = 0.0
    @Published var usageHistory: [DiskUsageSnapshot] = []
    
    // User-defined threshold for notifications (e.g., 0.1 for 10%)
    @Published var notificationThreshold: Double = 0.1
    @Published var isMonitoringEnabled: Bool = true

    private let historyKey = "com.hiddenbastard.diskusage.history"
    private let settingsKey = "com.hiddenbastard.diskusage.settings"
    private let maxHistoryDays = 30
    private var monitorTimer: Timer?

    init() {
        loadHistory()
        loadSettings()
        refresh()
        setupBackgroundMonitoring()
        requestNotificationPermission()
    }
    
    private func setupBackgroundMonitoring() {
        // Refresh every 30 minutes in background
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkDiskSpaceAndNotify()
            }
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }

    // Refresh disk space statistics
    func refresh() {
        guard let volumeURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }

        do {
            let values = try volumeURL.resourceValues(forKeys: [
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityKey
            ])

            if let total = values.volumeTotalCapacity,
               let available = values.volumeAvailableCapacity {
                self.totalSpace = UInt64(total)
                self.freeSpace = UInt64(available)
                self.usedSpace = self.totalSpace - self.freeSpace
                self.usagePercentage = Double(self.usedSpace) / Double(self.totalSpace)

                // Record snapshot
                recordSnapshot()
            }
        } catch {
            print("Error getting disk space: \(error)")
        }
    }
    
    func checkDiskSpaceAndNotify() {
        refresh()
        
        let freePercentage = 1.0 - usagePercentage
        if freePercentage < notificationThreshold && isMonitoringEnabled {
            sendLowDiskSpaceNotification(freePercentage: freePercentage)
        }
    }
    
    private func sendLowDiskSpaceNotification(freePercentage: Double) {
        let content = UNMutableNotificationContent()
        content.title = "Low Disk Space"
        content.body = String(format: "Your disk is almost full (%.1f%% free). Run Hidden Bastard to free up space.", freePercentage * 100)
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "com.hiddenbastard.lowdiskspace",
            content: content,
            trigger: nil // Deliver immediately
        )
        
        UNUserNotificationCenter.current().add(request)
    }

    // Get usage for a specific path
    func getUsageForPath(_ path: String) -> UInt64 {
        return getDirectorySize(atPath: path)
    }

    // Calculate directory size
    private func getDirectorySize(atPath path: String) -> UInt64 {
        var totalSize: UInt64 = 0

        guard let enumerator = FileManager.default.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey]
        ) else {
            return 0
        }

        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])

                if let isDirectory = resourceValues.isDirectory, !isDirectory {
                    if let fileSize = resourceValues.fileSize {
                        totalSize += UInt64(fileSize)
                    }
                }
            } catch {
                // Skip files we can't access
                continue
            }
        }

        return totalSize
    }

    // Record current disk usage snapshot
    private func recordSnapshot() {
        let snapshot = DiskUsageSnapshot(
            date: Date(),
            usedSpace: usedSpace,
            totalSpace: totalSpace
        )

        // Add to history
        usageHistory.append(snapshot)

        // Keep only last 30 days
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -maxHistoryDays, to: Date()) ?? Date()
        usageHistory = usageHistory.filter { $0.date >= cutoffDate }

        // Save to UserDefaults
        saveHistory()
    }

    // Get history for the last N days
    func getHistoryForDays(_ days: Int) -> [DiskUsageSnapshot] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return usageHistory.filter { $0.date >= cutoffDate }
    }

    // Get usage trend (increasing, decreasing, stable)
    func getUsageTrend() -> UsageTrend {
        let recentHistory = getHistoryForDays(7)
        guard recentHistory.count >= 2 else { return .stable }

        let oldestUsage = recentHistory.first!.usedSpace
        let newestUsage = recentHistory.last!.usedSpace

        let difference = Int64(newestUsage) - Int64(oldestUsage)
        let threshold: Int64 = 1_000_000_000 // 1GB

        if difference > threshold {
            return .increasing
        } else if difference < -threshold {
            return .decreasing
        } else {
            return .stable
        }
    }

    // Save history to UserDefaults
    private func saveHistory() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(usageHistory) {
            UserDefaults.standard.set(encoded, forKey: historyKey)
        }
        saveSettings()
    }
    
    private func saveSettings() {
        let settings: [String: Any] = [
            "notificationThreshold": notificationThreshold,
            "isMonitoringEnabled": isMonitoringEnabled
        ]
        UserDefaults.standard.set(settings, forKey: settingsKey)
    }

    // Load history from UserDefaults
    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: historyKey) else {
            return
        }

        let decoder = JSONDecoder()
        if let decoded = try? decoder.decode([DiskUsageSnapshot].self, from: data) {
            usageHistory = decoded
        }
    }
    
    private func loadSettings() {
        if let settings = UserDefaults.standard.dictionary(forKey: settingsKey) {
            notificationThreshold = settings["notificationThreshold"] as? Double ?? 0.1
            isMonitoringEnabled = settings["isMonitoringEnabled"] as? Bool ?? true
        }
    }

    // Format bytes to human-readable string
    func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useTB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

// Snapshot of disk usage at a point in time
struct DiskUsageSnapshot: Identifiable, Codable {
    let id = UUID()
    let date: Date
    let usedSpace: UInt64
    let totalSpace: UInt64

    var usagePercentage: Double {
        Double(usedSpace) / Double(totalSpace)
    }

    enum CodingKeys: String, CodingKey {
        case date, usedSpace, totalSpace
    }
}

// Disk usage trend
enum UsageTrend {
    case increasing
    case decreasing
    case stable

    var icon: String {
        switch self {
        case .increasing:
            return "arrow.up.right"
        case .decreasing:
            return "arrow.down.right"
        case .stable:
            return "arrow.right"
        }
    }

    var color: Color {
        switch self {
        case .increasing:
            return .red
        case .decreasing:
            return .green
        case .stable:
            return .blue
        }
    }

    var description: String {
        switch self {
        case .increasing:
            return "Disk usage is increasing"
        case .decreasing:
            return "Disk usage is decreasing"
        case .stable:
            return "Disk usage is stable"
        }
    }
}
