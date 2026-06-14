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

// Deletion history record
struct DeletionRecord: Identifiable, Codable {
    let id: UUID
    let name: String
    let path: String
    let size: UInt64
    let category: String
    let deletedAt: Date

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }
    var formattedDate: String {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f.string(from: deletedAt)
    }
}

// Plain English explanations for each category
struct CategoryInfo {
    let emoji: String
    let plain: String
    let safe: String

    static func for_(_ category: String) -> CategoryInfo {
        switch category {
        case "Incomplete Downloads":
            return CategoryInfo(emoji: "⬇️", plain: "Partial downloads that never finished — files your browser started grabbing but didn't complete. Totally safe to delete.", safe: "Safe")
        case "Application Caches":
            return CategoryInfo(emoji: "📦", plain: "Temporary files apps use to load faster. Apps rebuild these automatically. Deleting frees space with no permanent loss.", safe: "Safe")
        case "Developer Files":
            return CategoryInfo(emoji: "🔨", plain: "Build artifacts, compiled code, and tool caches from development work. Xcode/VS Code regenerates these. Safe unless you're mid-build.", safe: "Safe when not building")
        case "System Logs":
            return CategoryInfo(emoji: "📋", plain: "Log files macOS and apps write to track activity. Useful for debugging, but they accumulate forever. Safe to clear.", safe: "Safe")
        case "Trash Items":
            return CategoryInfo(emoji: "🗑️", plain: "Files already in your Trash. Permanently removes them from disk.", safe: "Permanent — review first")
        case "Docker":
            return CategoryInfo(emoji: "🐳", plain: "Docker container data and volumes. Only delete if you're sure you don't need these containers.", safe: "Verify first")
        case "Large App Data":
            return CategoryInfo(emoji: "🗄️", plain: "Big folders inside Application Support, Containers, and Developer — browser AI models, app data, simulator devices, and the like. Some is reclaimable, but this also holds real data like profiles and logins. Review each item before deleting.", safe: "Review carefully — holds real data")
        default:
            return CategoryInfo(emoji: "📁", plain: "Files that may be taking up unnecessary space.", safe: "Review before deleting")
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