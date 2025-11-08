import Foundation
import SwiftUI

// Problem file model
struct ProblemFile: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let size: UInt64
    let dateModified: Date
    let category: String
    let riskLevel: RiskLevel
    var isSelected: Bool = false

    // Helper for displaying file size in human-readable format
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }

    // Helper for displaying date in readable format
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: dateModified)
    }
}

// Risk level enum for categorizing files
enum RiskLevel: String, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"

    var color: Color {
        switch self {
        case .low:
            return .green
        case .medium:
            return .yellow
        case .high:
            return .red
        }
    }
}

// Disk space usage item for visualization
struct DiskSpaceItem: Identifiable {
    let id = UUID()
    let name: String
    let size: UInt64
    let percentage: Double
    let color: Color
}