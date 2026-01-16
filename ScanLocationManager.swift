import Foundation
import AppKit

// Manages user-selected scan locations with security-scoped bookmarks
class ScanLocationManager: ObservableObject {
    @Published var scanLocations: [ScanLocation] = []

    private let bookmarksKey = "com.hiddenbastard.scanlocations.bookmarks"

    init() {
        loadSavedLocations()
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

    // Get default scan locations (user-accessible only)
    func getDefaultLocations() -> [ScanLocation] {
        var locations: [ScanLocation] = []

        // Downloads folder
        if let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first {
            locations.append(ScanLocation(
                id: UUID(),
                url: downloadsURL,
                name: "Downloads",
                path: downloadsURL.path,
                bookmarkData: nil,
                categories: ["Incomplete Downloads"],
                isEnabled: true
            ))
        }

        // User Library Caches
        if let libraryURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first {
            let cachesURL = libraryURL.appendingPathComponent("Caches")
            locations.append(ScanLocation(
                id: UUID(),
                url: cachesURL,
                name: "Application Caches",
                path: cachesURL.path,
                bookmarkData: nil,
                categories: ["Application Caches"],
                isEnabled: true
            ))

            // User Logs
            let logsURL = libraryURL.appendingPathComponent("Logs")
            locations.append(ScanLocation(
                id: UUID(),
                url: logsURL,
                name: "Application Logs",
                path: logsURL.path,
                bookmarkData: nil,
                categories: ["System Logs"],
                isEnabled: true
            ))

            // Developer folder (if exists)
            let developerURL = libraryURL.appendingPathComponent("Developer")
            if FileManager.default.fileExists(atPath: developerURL.path) {
                locations.append(ScanLocation(
                    id: UUID(),
                    url: developerURL,
                    name: "Developer Files",
                    path: developerURL.path,
                    bookmarkData: nil,
                    categories: ["Developer Files"],
                    isEnabled: true
                ))
            }
        }

        // Trash
        if let trashURL = FileManager.default.urls(for: .trashDirectory, in: .userDomainMask).first {
            locations.append(ScanLocation(
                id: UUID(),
                url: trashURL,
                name: "Trash",
                path: trashURL.path,
                bookmarkData: nil,
                categories: ["Trash Items"],
                isEnabled: true
            ))
        }

        return locations
    }

    // Resolve a security-scoped bookmark to get access to the URL
    func resolveBookmark(for location: ScanLocation) -> URL? {
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
