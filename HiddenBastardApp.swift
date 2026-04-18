import SwiftUI

@main
struct HiddenBastardApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Hidden Bastard") {
                    NSApplication.shared.orderFrontStandardAboutPanel(
                        options: [
                            NSApplication.AboutPanelOptionKey.applicationName: "Hidden Bastard",
                            NSApplication.AboutPanelOptionKey.applicationVersion: "1.0.0",
                            NSApplication.AboutPanelOptionKey.credits: NSAttributedString(
                                string: "The Pro-Grade System Maintenance Utility",
                                attributes: [NSAttributedString.Key.font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)]
                            )
                        ]
                    )
                }
                Button("Check for Updates...") {
                    UpdateChecker.checkForUpdates(silent: false)
                }
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    UpdateChecker.checkForUpdates()
                }
            }
        }
    }
}
