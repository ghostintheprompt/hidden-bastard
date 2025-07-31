import SwiftUI

@main
struct HiddenBastardApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
                .onAppear {
                    // Request full disk access on launch
                    requestFullDiskAccess()
                }
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .commands {
            // Add app menu commands
            CommandGroup(replacing: .appInfo) {
                Button("About Hidden Bastard") {
                    NSApplication.shared.orderFrontStandardAboutPanel(
                        options: [
                            NSApplication.AboutPanelOptionKey.applicationName: "Hidden Bastard File Deleter",
                            NSApplication.AboutPanelOptionKey.applicationVersion: "1.0",
                            NSApplication.AboutPanelOptionKey.credits: NSAttributedString(
                                string: "Finds and deletes hidden files taking up your disk space",
                                attributes: [NSAttributedString.Key.font: NSFont.systemFont(ofSize: 11)]
                            )
                        ]
                    )
                }
            }
        }
    }
    
    // Helper method to request full disk access
    private func requestFullDiskAccess() {
        // In a real app, this would guide the user to System Preferences > Security & Privacy > Privacy > Full Disk Access
        // Here we're just showing a notification about it
        print("Full disk access required for complete system scanning")
    }
}