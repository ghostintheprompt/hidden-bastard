import SwiftUI

@main
struct HiddenBastardApp: App {
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
                            NSApplication.AboutPanelOptionKey.applicationVersion: "2.0",
                            NSApplication.AboutPanelOptionKey.credits: NSAttributedString(
                                string: "The Pro-Grade System Maintenance Utility",
                                attributes: [NSAttributedString.Key.font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)]
                            )
                        ]
                    )
                }
            }
        }
    }
}
