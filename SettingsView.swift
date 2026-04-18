import SwiftUI

struct SettingsView: View {
    @AppStorage("autoScanOnLaunch") private var autoScanOnLaunch = false
    @AppStorage("showNotifications") private var showNotifications = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("SETTINGS")
                    .font(.system(.headline, design: .monospaced))
                    .foregroundColor(AppTheme.primaryColor)

                // Behavior
                DarkSettingsSection(title: "BEHAVIOR") {
                    VStack(spacing: 16) {
                        DarkToggleRow(
                            title: "Auto-scan on launch",
                            subtitle: "Run a scan automatically when you open the app",
                            isOn: $autoScanOnLaunch
                        )
                        DarkToggleRow(
                            title: "Show notifications",
                            subtitle: "Alert you when a scan finds something large",
                            isOn: $showNotifications
                        )
                    }
                }

                // Privacy
                DarkSettingsSection(title: "PRIVACY") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.shield.fill")
                                .foregroundColor(AppTheme.successColor)
                            Text("Everything runs locally on your machine.")
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        Text("No data is transmitted. No telemetry. No tracking. Open source — read the code.")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(AppTheme.neutralColor)
                    }
                }

                // About
                DarkSettingsSection(title: "ABOUT") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            AppIcon(size: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("HIDDEN BASTARD")
                                    .font(.system(.body, design: .monospaced))
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                Text("V 1.0.0 // macOS Junk File Eliminator")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(AppTheme.neutralColor)
                            }
                        }
                        Text("Finds and removes hidden system files consuming unnecessary disk space. Xcode build artifacts, caches, logs, old backups — the junk macOS never tells you about.")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(AppTheme.neutralColor)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer()
            }
            .padding(24)
        }
        .colorScheme(.dark)
    }
}

struct DarkSettingsSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(AppTheme.primaryColor)
            content
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.surfaceColor)
                .overlay(Rectangle().stroke(AppTheme.primaryColor.opacity(0.2), lineWidth: 1))
        }
    }
}

struct DarkToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(AppTheme.neutralColor)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .toggleStyle(CustomToggleStyle())
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
