import Foundation
import AppKit

// Manages user-selected scan locations with security-scoped bookmarks
@MainActor
class ScanLocationManager: ObservableObject {
    @Published var scanLocations: [ScanLocation] = []
    @Published var excludedPaths: [String] = []

    private let bookmarksKey = "com.hiddenbastard.scanlocations.bookmarks"
    private let exclusionsKey = "com.hiddenbastard.scanlocations.exclusions"

    init() {
        loadSavedLocations()
        loadExclusions()
    }
    
    func addExclusion(path: String) {
        if !excludedPaths.contains(path) {
            excludedPaths.append(path)
            saveExclusions()
        }
    }
    
    func removeExclusion(at offsets: IndexSet) {
        excludedPaths.remove(atOffsets: offsets)
        saveExclusions()
    }
    
    func isPathExcluded(_ path: String) -> Bool {
        return excludedPaths.contains { path.hasPrefix($0) }
    }

    // Add a new location using NSOpenPanel
    func addLocation(categories: [String], completion: @escaping (Bool) -> Void) {
        let panel = NSOpenPanel()
        panel.message = "Choose a folder to scan for hidden files"
        panel.prompt = "Select Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false

        panel.begin { response in
            guard response == .OK, let url = panel.url else {
                completion(false)
                return
            }

            // Create security-scoped bookmark for persistent access
            do {
                let bookmarkData = try url.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )

                let location = ScanLocation(
                    id: UUID(),
                    url: url,
                    name: url.lastPathComponent,
                    path: url.path,
                    bookmarkData: bookmarkData,
                    categories: categories,
                    isEnabled: true
                )

                DispatchQueue.main.async {
                    self.scanLocations.append(location)
                    self.saveLocations()
                    completion(true)
                }
            } catch {
                print("Failed to create bookmark: \(error)")
                completion(false)
            }
        }
    }

    // Get default scan locations
    func getDefaultLocations() -> [ScanLocation] {
        var locations: [ScanLocation] = []
        let home = FileManager.default.homeDirectoryForCurrentUser
        let fm = FileManager.default

        func add(_ path: String, name: String, category: String, enabled: Bool = true) {
            let url = URL(fileURLWithPath: path)
            if fm.fileExists(atPath: path) {
                locations.append(ScanLocation(id: UUID(), url: url, name: name, path: path, bookmarkData: nil, categories: [category], isEnabled: enabled))
            }
        }

        // Downloads
        if let url = fm.urls(for: .downloadsDirectory, in: .userDomainMask).first {
            add(url.path, name: "Downloads", category: "Incomplete Downloads")
        }

        // Trash
        if let url = fm.urls(for: .trashDirectory, in: .userDomainMask).first {
            add(url.path, name: "Trash", category: "Trash Items")
        }

        let lib = home.appendingPathComponent("Library").path

        // App caches
        add("\(lib)/Caches", name: "Application Caches", category: "Application Caches")

        // Logs
        add("\(lib)/Logs", name: "Application Logs", category: "System Logs")

        // iOS Backups
        add("\(lib)/Application Support/MobileSync/Backup", name: "iOS Backups", category: "Developer Files")

        // Xcode DerivedData
        add("\(lib)/Developer/Xcode/DerivedData", name: "Xcode DerivedData", category: "Developer Files")

        // Xcode Archives
        add("\(lib)/Developer/Xcode/Archives", name: "Xcode Archives", category: "Developer Files")

        // CocoaPods cache
        add("\(lib)/Caches/CocoaPods", name: "CocoaPods Cache", category: "Developer Files")

        // npm cache
        add(home.appendingPathComponent(".npm").path, name: "npm Cache", category: "Developer Files")

        // Yarn cache
        add(home.appendingPathComponent(".yarn/cache").path, name: "Yarn Cache", category: "Developer Files")

        // Xcode iOS/watchOS DeviceSupport (huge symbol files per iOS version)
        add("\(lib)/Developer/Xcode/iOS DeviceSupport", name: "Xcode iOS DeviceSupport", category: "Developer Files")
        add("\(lib)/Developer/Xcode/watchOS DeviceSupport", name: "Xcode watchOS DeviceSupport", category: "Developer Files")

        // VS Code workspace storage and extension cache
        add("\(lib)/Application Support/Code/User/workspaceStorage", name: "VS Code Workspace Storage", category: "Developer Files")
        add("\(lib)/Application Support/Code/CachedExtensionVSIXs", name: "VS Code Extension Cache", category: "Developer Files")
        add("\(lib)/Application Support/Code/logs", name: "VS Code Logs", category: "System Logs")

        // Simulator runtimes
        add("\(lib)/Developer/CoreSimulator/Caches", name: "Simulator Caches", category: "Developer Files")

        // Crash logs and diagnostic reports
        add("\(lib)/Logs/DiagnosticReports", name: "Crash Reports", category: "System Logs")
        add("\(lib)/Logs/CrashReporter", name: "Crash Reporter Logs", category: "System Logs")

        // Python virtual environments (scan common locations)
        add(home.appendingPathComponent(".virtualenvs").path, name: "Python Virtualenvs", category: "Developer Files")
        add(home.appendingPathComponent(".pyenv/versions").path, name: "pyenv Versions", category: "Developer Files")

        // Gradle cache
        add(home.appendingPathComponent(".gradle/caches").path, name: "Gradle Cache", category: "Developer Files")

        // Homebrew cache
        add(home.appendingPathComponent("Library/Caches/Homebrew").path, name: "Homebrew Cache", category: "Application Caches")

        return locations
    }

    // Resolve a security-scoped bookmark to get access to the URL
    nonisolated func resolveBookmark(for location: ScanLocation) -> URL? {
        guard let bookmarkData = location.bookmarkData else {
            return location.url
        }

        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                // Bookmark is stale, need to recreate it
                print("Bookmark is stale for: \(location.name)")
            }

            return url
        } catch {
            print("Failed to resolve bookmark: \(error)")
            return nil
        }
    }

    // Save locations to UserDefaults
    private func saveLocations() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(scanLocations) {
            UserDefaults.standard.set(encoded, forKey: bookmarksKey)
        }
    }
    
    private func saveExclusions() {
        UserDefaults.standard.set(excludedPaths, forKey: exclusionsKey)
    }

    // Load locations from UserDefaults
    private func loadSavedLocations() {
        guard let data = UserDefaults.standard.data(forKey: bookmarksKey) else {
            // No saved locations, use defaults
            scanLocations = getDefaultLocations()
            return
        }

        let decoder = JSONDecoder()
        if let decoded = try? decoder.decode([ScanLocation].self, from: data) {
            scanLocations = decoded
        } else {
            scanLocations = getDefaultLocations()
        }
    }
    
    private func loadExclusions() {
        excludedPaths = UserDefaults.standard.stringArray(forKey: exclusionsKey) ?? [
            "/System",
            "/Library",
            "/bin",
            "/sbin"
        ]
    }

    // Remove a location
    func removeLocation(at offsets: IndexSet) {
        scanLocations.remove(atOffsets: offsets)
        saveLocations()
    }

    // Toggle location enabled state
    func toggleLocation(_ location: ScanLocation) {
        if let index = scanLocations.firstIndex(where: { $0.id == location.id }) {
            scanLocations[index].isEnabled.toggle()
            saveLocations()
        }
    }
}

// Model for a scan location
struct ScanLocation: Identifiable, Codable {
    let id: UUID
    let url: URL
    let name: String
    let path: String
    let bookmarkData: Data?
    let categories: [String]
    var isEnabled: Bool
}
