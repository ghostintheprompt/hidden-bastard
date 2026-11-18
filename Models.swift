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

    var assessment: ItemAssessment {
        let lowercasedPath = path.lowercased()
        if let protectedReason = Self.protectedDataReason(in: lowercasedPath) {
            return ItemAssessment(label: "Protected data", explanation: protectedReason, canSelect: false)
        }

        let age = Date().timeIntervalSince(dateModified)
        let recentlyChanged = age < 30 * 24 * 60 * 60

        switch category {
        case "Incomplete Downloads":
            if age < 7 * 24 * 60 * 60 {
                return ItemAssessment(label: "Possibly still downloading", explanation: "This partial download changed within the last 7 days. It may still be in progress, so it is not preselected.", canSelect: false)
            }
            return ItemAssessment(label: "Old partial download", explanation: "A partial download unchanged for at least 7 days. Confirm you do not want to resume it.", canSelect: true)
        case "Application Caches":
            if recentlyChanged {
                return ItemAssessment(label: "Recently changed cache", explanation: "Apps can recreate cache data, but its timestamp is recent. A folder timestamp does not prove whether its contents are in use, so review before removal.", canSelect: false)
            }
            return ItemAssessment(label: "Regenerable cache", explanation: "This is app cache data, not project source. Its timestamp is at least 30 days old; timestamps alone cannot prove it is unused.", canSelect: true)
        case "Developer Files":
            return ItemAssessment(label: "Development-related", explanation: "\(knownPurpose(for: lowercasedPath)) It can support existing projects or builds; review before removing.", canSelect: true)
        case "System Logs":
            return ItemAssessment(label: "Diagnostic data", explanation: "Logs can help diagnose problems and may still be written by running apps. Review before removal.", canSelect: true)
        case "Trash Items":
            return ItemAssessment(label: "Already in Trash", explanation: "This is already discarded. Removing it may be difficult to undo; review before proceeding.", canSelect: true)
        case "Large Downloads":
            return ItemAssessment(label: "Large complete download", explanation: "This is not a recognized partial-download file. It may be an installer, archive, or work file you still need.", canSelect: true)
        case "Large App Data":
            return largeDataAssessment(path: lowercasedPath, recentlyChanged: recentlyChanged)
        default:
            return ItemAssessment(label: "Unclassified", explanation: "Hidden Bastard cannot identify this item confidently. Last modified: \(formattedDate). Its age alone does not prove it is unused.", canSelect: false)
        }
    }

    var isEligibleForAutoSelection: Bool {
        riskLevel == .low && assessment.canSelect && category != "Trash Items"
    }

    private func largeDataAssessment(path: String, recentlyChanged: Bool) -> ItemAssessment {
        if path.hasPrefix("/applications/") {
            return ItemAssessment(label: "Installed application", explanation: "This appears to be an installed app bundle. Remove it through its normal uninstaller or Applications, not as cache cleanup.", canSelect: false)
        }
        if path.contains("/.colima") {
            return ItemAssessment(label: "Colima virtual machine", explanation: "Can contain Linux VM disks, containers, images, and databases. \(activityClue(recentlyChanged)); keep it if any container or volume matters.", canSelect: true)
        }
        if path.contains("/.codex") {
            return ItemAssessment(label: "Codex local data", explanation: "May contain Codex settings, local history, and supporting data. \(activityClue(recentlyChanged)); this is not assumed to be disposable cache.", canSelect: true)
        }
        if path.contains("/.ollama") {
            return ItemAssessment(label: "Local AI models", explanation: "Downloaded Ollama models can be reused offline; deleting them means downloading them again. \(activityClue(recentlyChanged)); review whether you still use them.", canSelect: true)
        }
        if let attributes = try? FileManager.default.attributesOfItem(atPath: self.path),
           let type = attributes[.type] as? FileAttributeType,
           type == .typeRegular {
            return ItemAssessment(label: "Large file", explanation: "A large file outside the known cleanup locations. Its purpose is not identified; review the full path and timestamp before removing it.", canSelect: true)
        }
        if hasProjectMarkers(at: self.path) {
            return ItemAssessment(label: "Source project", explanation: "Contains project markers such as Git metadata or a build manifest. \(activityClue(recentlyChanged)); do not remove it as cleanup unless you have archived the work.", canSelect: true)
        }
        return ItemAssessment(label: "Application or user data", explanation: "\(knownPurpose(for: path)) \(activityClue(recentlyChanged)); the folder name and age cannot establish that it is no longer needed.", canSelect: true)
    }

    private func activityClue(_ recentlyChanged: Bool) -> String {
        recentlyChanged
            ? "The folder timestamp is within the last 30 days"
            : "The folder timestamp is older than 30 days"
    }

    private func knownPurpose(for path: String) -> String {
        if path.contains("/.net/azmcp") { return "Azure MCP helper libraries, including speech and Microsoft sign-in components; keep them if Azure MCP is in use." }
        if path.contains("/.agents/skills") { return "Installed AI-agent skill instructions and resources; this is active tool configuration, not disposable cache." }
        if path.contains("/.aider") { return "Aider AI coding assistant metadata and caches; preserve it if Aider is part of your workflow." }
        if path.contains("/.android") { return "Android SDK/emulator metadata and caches; useful for Android work, with some cache data regenerable." }
        if path.contains("/.dart-tool") { return "Dart/Flutter tool state and telemetry created by the Dart tooling." }
        if path.contains("/.templateengine") { return ".NET CLI template packages used by dotnet new; generally regenerable but small." }
        if path.contains("/.matplotlib") { return "Matplotlib plotting configuration and generated font-list cache." }
        if path.contains("/.cline") { return "Cline editor-extension settings and workspace state; may include useful history." }
        if path.contains("/.vscode-shared") { return "Shared VS Code workspace state and backups." }
        if path.contains("/.zsh_sessions") { return "Terminal session and command-history state; it may contain useful commands or sensitive text." }
        if path.contains("/.aspnet") { return "ASP.NET local development state, including HTTPS development certificates." }
        if path.contains("/.claude.json") { return "Claude Code settings and local account/workspace state." }
        if path.contains("/.npm") { return "npm package-download cache, used by JavaScript installs and builds." }
        if path.contains("/.gradle") { return "Gradle build and dependency data, used by Android/JVM projects." }
        if path.contains("/.vscode") { return "VS Code settings, extensions, and workspace state." }
        if path.contains("/.copilot") || path.contains("/.continue") || path.contains("/.claude") {
            return "AI coding-tool settings and local state."
        }
        if path.contains("/.pub-cache") { return "Dart/Flutter package cache used by projects." }
        if path.contains("/nltk_data") { return "NLTK datasets for Python language-processing projects; WordNet is one common corpus." }
        if path.contains("/.cache") { return "A shared application/tool cache; contents depend on which programs created it." }
        return "Large folder found outside the known cleanup locations."
    }

    private func hasProjectMarkers(at path: String) -> Bool {
        let markers = [".git", "Package.swift", "package.json", "Cargo.toml", "pyproject.toml"]
        if markers.contains(where: {
            FileManager.default.fileExists(atPath: (path as NSString).appendingPathComponent($0))
        }) {
            return true
        }
        let children = (try? FileManager.default.contentsOfDirectory(atPath: path)) ?? []
        return children.contains { $0.hasSuffix(".xcodeproj") || $0.hasSuffix(".xcworkspace") }
    }

    private static func protectedDataReason(in path: String) -> String? {
        let protectedFragments = [
            "/library/keychains",
            "/library/application support/google",
            "/library/application support/mozilla",
            "/library/application support/microsoft",
            "/library/application support/chromium",
            "/library/safari",
            "/.ssh",
            "/.gnupg",
            "/.aws",
            "/.azure",
            "/.config",
            "/.claude.json",
            "/.zsh_sessions",
            "/.aspnet/dev-certs",
            "/.mozilla",
            "/.password-store",
            "/.npmrc",
            "/.pypirc",
            "/.netrc",
            "/.docker",
            "/.git-credentials",
            "1password",
            "bitwarden",
            "lastpass",
            "dashlane",
            "keepass",
            "password",
            "credential",
            "login data",
            "logins.json"
        ]
        guard protectedFragments.contains(where: { path.contains($0) }) else { return nil }
        return "This path can contain passwords, sign-ins, encryption keys, or browser profile data. Hidden Bastard will not select or move it."
    }
}

struct ItemAssessment {
    let label: String
    let explanation: String
    let canSelect: Bool
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
            return CategoryInfo(emoji: "⬇️", plain: "Files with known partial-download suffixes. Recent files may still be downloading; only older partials are preselected.", safe: "Review recent files")
        case "Application Caches":
            return CategoryInfo(emoji: "📦", plain: "Regenerable app data. Recently changed caches are not preselected in case they are in active use.", safe: "Old caches only")
        case "Developer Files":
            return CategoryInfo(emoji: "🔨", plain: "Build artifacts and package data may support current freelance projects. Check the tool, project, and recent activity before removing.", safe: "Review before deleting")
        case "System Logs":
            return CategoryInfo(emoji: "📋", plain: "Diagnostic logs can help troubleshoot problems and may still be written by running apps.", safe: "Review before deleting")
        case "Trash Items":
            return CategoryInfo(emoji: "🗑️", plain: "Files already discarded to Trash. Removing them may be difficult to undo.", safe: "Review first")
        case "Docker":
            return CategoryInfo(emoji: "🐳", plain: "Docker container data and volumes. Only delete if you're sure you don't need these containers.", safe: "Verify first")
        case "Large App Data":
            return CategoryInfo(emoji: "🗄️", plain: "Large folders outside the known cleanup list. Hidden Bastard identifies recognized tools and project markers, but unknown app data may still matter.", safe: "Review each item")
        case "Large Downloads":
            return CategoryInfo(emoji: "📥", plain: "Large completed downloads such as installers, archives, or work files. They are surfaced for visibility, not assumed to be junk.", safe: "Review before deleting")
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