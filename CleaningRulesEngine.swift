import Foundation
import SwiftUI

// Manages automated cleaning rules
@MainActor
class RulesEngine: ObservableObject {
    @Published var rules: [CleaningRule] = []

    private let rulesKey = "com.hiddenbastard.cleaningrules"
    private let lastRunKey = "com.hiddenbastard.cleaningrules.lastrun"

    init() {
        loadRules()
    }

    // Add a new rule
    func addRule(_ rule: CleaningRule) {
        rules.append(rule)
        saveRules()
    }

    // Update an existing rule
    func updateRule(_ rule: CleaningRule) {
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[index] = rule
            saveRules()
        }
    }

    // Delete a rule
    func deleteRule(at offsets: IndexSet) {
        rules.remove(atOffsets: offsets)
        saveRules()
    }

    // Toggle rule enabled state
    func toggleRule(_ rule: CleaningRule) {
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[index].isEnabled.toggle()
            saveRules()
        }
    }

    // Execute a specific rule
    func executeRule(_ rule: CleaningRule, completion: @escaping (RuleExecutionResult) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let result = self.performRuleExecution(rule)

            // Update last run time
            var updatedRule = rule
            updatedRule.lastRun = Date()
            self.updateRule(updatedRule)

            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    // Check if any rules should run based on their schedule
    func checkAndExecuteDueRules(completion: @escaping ([RuleExecutionResult]) -> Void) {
        let dueRules = rules.filter { rule in
            rule.isEnabled && self.shouldRuleRun(rule)
        }

        guard !dueRules.isEmpty else {
            completion([])
            return
        }

        var results: [RuleExecutionResult] = []

        let group = DispatchGroup()

        for rule in dueRules {
            group.enter()
            executeRule(rule) { result in
                results.append(result)
                group.leave()
            }
        }

        group.notify(queue: DispatchQueue.main) {
            completion(results)
        }
    }

    // Determine if a rule should run based on its schedule
    private func shouldRuleRun(_ rule: CleaningRule) -> Bool {
        guard let lastRun = rule.lastRun else {
            // Never run before
            return true
        }

        let calendar = Calendar.current
        let now = Date()

        switch rule.schedule {
        case .hourly:
            return calendar.dateComponents([.hour], from: lastRun, to: now).hour ?? 0 >= 1
        case .daily:
            return calendar.dateComponents([.day], from: lastRun, to: now).day ?? 0 >= 1
        case .weekly:
            return calendar.dateComponents([.day], from: lastRun, to: now).day ?? 0 >= 7
        case .monthly:
            return calendar.dateComponents([.month], from: lastRun, to: now).month ?? 0 >= 1
        case .manual:
            return false
        }
    }

    // Perform the actual rule execution
    private func performRuleExecution(_ rule: CleaningRule) -> RuleExecutionResult {
        var deletedFiles: [String] = []
        var freedSpace: UInt64 = 0
        var errors: [String] = []

        for target in rule.targets {
            let expandedPath = NSString(string: target.path).expandingTildeInPath

            // Check if path exists
            guard FileManager.default.fileExists(atPath: expandedPath) else {
                errors.append("Path not found: \(target.path)")
                continue
            }

            // Find files matching the criteria
            let matchingFiles = findMatchingFiles(
                path: expandedPath,
                sizeThreshold: target.sizeThreshold,
                ageThreshold: target.ageThreshold,
                pattern: target.pattern,
                action: target.action
            )

            // Execute the action on matching files
            for file in matchingFiles {
                do {
                    let attributes = try FileManager.default.attributesOfItem(atPath: file)
                    let fileSize = attributes[.size] as? UInt64 ?? 0

                    switch target.action {
                    case .delete:
                        try FileManager.default.removeItem(atPath: file)
                        deletedFiles.append(file)
                        freedSpace += fileSize

                    case .moveToTrash:
                        try FileManager.default.trashItem(at: URL(fileURLWithPath: file), resultingItemURL: nil)
                        deletedFiles.append(file)
                        freedSpace += fileSize

                    case .compress:
                        // Compression would be implemented here
                        // For now, just log it
                        print("Would compress: \(file)")
                    }
                } catch {
                    errors.append("Error processing \(file): \(error.localizedDescription)")
                }
            }
        }

        return RuleExecutionResult(
            ruleId: rule.id,
            ruleName: rule.name,
            executionDate: Date(),
            filesProcessed: deletedFiles.count,
            spaceFreed: freedSpace,
            errors: errors
        )
    }

    // Find files matching the target criteria
    private func findMatchingFiles(
        path: String,
        sizeThreshold: UInt64?,
        ageThreshold: TimeInterval?,
        pattern: String?,
        action: RuleAction
    ) -> [String] {
        var matchingFiles: [String] = []

        guard let enumerator = FileManager.default.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]
        ) else {
            return []
        }

        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(
                    forKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey]
                )

                // Skip directories unless explicitly targeting them
                if let isDirectory = resourceValues.isDirectory, isDirectory {
                    continue
                }

                var matches = true

                // Check size threshold
                if let sizeThreshold = sizeThreshold,
                   let fileSize = resourceValues.fileSize {
                    matches = matches && UInt64(fileSize) > sizeThreshold
                }

                // Check age threshold
                if let ageThreshold = ageThreshold,
                   let modificationDate = resourceValues.contentModificationDate {
                    let age = Date().timeIntervalSince(modificationDate)
                    matches = matches && age > ageThreshold
                }

                // Check pattern
                if let pattern = pattern,
                   let regex = try? NSRegularExpression(pattern: pattern) {
                    let filename = fileURL.lastPathComponent
                    let range = NSRange(location: 0, length: filename.utf16.count)
                    matches = matches && regex.firstMatch(in: filename, range: range) != nil
                }

                if matches {
                    matchingFiles.append(fileURL.path)
                }
            } catch {
                // Skip files we can't access
                continue
            }
        }

        return matchingFiles
    }

    // Save rules to UserDefaults
    private func saveRules() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(rules) {
            UserDefaults.standard.set(encoded, forKey: rulesKey)
        }
    }

    // Load rules from UserDefaults
    private func loadRules() {
        guard let data = UserDefaults.standard.data(forKey: rulesKey) else {
            // Create some default rules
            rules = getDefaultRules()
            return
        }

        let decoder = JSONDecoder()
        if let decoded = try? decoder.decode([CleaningRule].self, from: data) {
            rules = decoded
        } else {
            rules = getDefaultRules()
        }
    }

    // Get default rules for first-time users
    private func getDefaultRules() -> [CleaningRule] {
        return [
            CleaningRule(
                name: "Clean Download Fragments",
                description: "Remove incomplete download files older than 7 days",
                icon: "arrow.down.circle",
                targets: [
                    RuleTarget(
                        path: "~/Downloads",
                        pattern: "\\.part$|\\.download$|\\.crdownload$",
                        sizeThreshold: 1_000_000, // 1MB
                        ageThreshold: 7 * 24 * 3600, // 7 days
                        action: .moveToTrash
                    )
                ],
                schedule: .weekly,
                isEnabled: false,
                lastRun: nil
            ),
            CleaningRule(
                name: "Clean Application Caches",
                description: "Remove cache files larger than 500MB",
                icon: "folder",
                targets: [
                    RuleTarget(
                        path: "~/Library/Caches",
                        pattern: nil,
                        sizeThreshold: 500_000_000, // 500MB
                        ageThreshold: nil,
                        action: .delete
                    )
                ],
                schedule: .monthly,
                isEnabled: false,
                lastRun: nil
            )
        ]
    }
}

// Model for a cleaning rule
struct CleaningRule: Identifiable, Codable {
    let id: UUID
    var name: String
    var description: String
    var icon: String
    var targets: [RuleTarget]
    var schedule: RuleSchedule
    var isEnabled: Bool
    var lastRun: Date?

    init(id: UUID = UUID(), name: String, description: String, icon: String, targets: [RuleTarget], schedule: RuleSchedule, isEnabled: Bool, lastRun: Date?) {
        self.id = id
        self.name = name
        self.description = description
        self.icon = icon
        self.targets = targets
        self.schedule = schedule
        self.isEnabled = isEnabled
        self.lastRun = lastRun
    }
}

// Target for a cleaning rule
struct RuleTarget: Codable {
    var path: String
    var pattern: String?
    var sizeThreshold: UInt64?
    var ageThreshold: TimeInterval?
    var action: RuleAction
}

// Rule schedule
enum RuleSchedule: String, Codable, CaseIterable {
    case manual = "Manual"
    case hourly = "Hourly"
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
}

// Rule action
enum RuleAction: String, Codable, CaseIterable {
    case delete = "Delete"
    case moveToTrash = "Move to Trash"
    case compress = "Compress"
}

// Result of rule execution
struct RuleExecutionResult: Identifiable {
    let id = UUID()
    let ruleId: UUID
    let ruleName: String
    let executionDate: Date
    let filesProcessed: Int
    let spaceFreed: UInt64
    let errors: [String]

    var wasSuccessful: Bool {
        errors.isEmpty
    }
}
