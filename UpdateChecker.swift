import Foundation
import AppKit

struct UpdateChecker {
    static let currentVersion = "1.0.0"
    private static let releasesURL = "https://api.github.com/repos/ghostintheprompt/hidden-bastard/releases/latest"

    static func checkForUpdates(silent: Bool = true) {
        guard let url = URL(string: releasesURL) else { return }

        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data, error == nil,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = json["tag_name"] as? String,
                  let htmlURL = json["html_url"] as? String else {
                return
            }

            let latest = tag.trimmingCharacters(in: CharacterSet(charactersIn: "v"))

            if isNewer(latest, than: currentVersion) {
                DispatchQueue.main.async {
                    showUpdateAlert(version: latest, url: htmlURL)
                }
            }
        }.resume()
    }

    private static func isNewer(_ remote: String, than local: String) -> Bool {
        let r = remote.split(separator: ".").compactMap { Int($0) }
        let l = local.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(r.count, l.count) {
            let rv = i < r.count ? r[i] : 0
            let lv = i < l.count ? l[i] : 0
            if rv != lv { return rv > lv }
        }
        return false
    }

    private static func showUpdateAlert(version: String, url: String) {
        let alert = NSAlert()
        alert.messageText = "Update Available — v\(version)"
        alert.informativeText = "A new version of Hidden Bastard is available. Download it from GitHub Releases."
        alert.addButton(withTitle: "Download")
        alert.addButton(withTitle: "Later")
        alert.alertStyle = .informational

        if alert.runModal() == .alertFirstButtonReturn,
           let releaseURL = URL(string: url) {
            NSWorkspace.shared.open(releaseURL)
        }
    }
}
