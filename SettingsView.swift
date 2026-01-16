import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("autoScanOnLaunch") private var autoScanOnLaunch = false
    @AppStorage("showNotifications") private var showNotifications = true
    @AppStorage("minimizeToMenuBar") private var minimizeToMenuBar = false
    @AppStorage("darkModeOverride") private var darkModeOverride = false
    @AppStorage("scanThreshold") private var scanThreshold = 100.0 // MB

    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Tab selection
            HStack(spacing: 0) {
                SettingsTabButton(
                    title: "General",
                    icon: "gearshape",
                    isSelected: selectedTab == 0,
                    action: { selectedTab = 0 }
                )

                SettingsTabButton(
                    title: "Scanning",
                    icon: "magnifyingglass",
                    isSelected: selectedTab == 1,
                    action: { selectedTab = 1 }
                )

                SettingsTabButton(
                    title: "About",
                    icon: "info.circle",
                    isSelected: selectedTab == 2,
                    action: { selectedTab = 2 }
                )
            }
            .padding(.horizontal)
            .padding(.top, 8)

            Divider()
                .padding(.top, 8)

            // Content
            TabView(selection: $selectedTab) {
                generalSettings
                    .tag(0)

                scanningSettings
                    .tag(1)

                aboutSettings
                    .tag(2)
            }
            .tabViewStyle(.automatic)
        }
        .frame(width: 600, height: 500)
    }

    var generalSettings: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.standardPadding) {
                SettingsSection(title: "Behavior") {
                    VStack(spacing: 12) {
                        Toggle("Auto-scan on launch", isOn: $autoScanOnLaunch)
                            .toggleStyle(CustomToggleStyle())

                        Toggle("Show notifications", isOn: $showNotifications)
                            .toggleStyle(CustomToggleStyle())

                        Toggle("Minimize to menu bar", isOn: $minimizeToMenuBar)
                            .toggleStyle(CustomToggleStyle())
                    }
                }

                SettingsSection(title: "Appearance") {
                    Toggle("Force dark mode", isOn: $darkModeOverride)
                        .toggleStyle(CustomToggleStyle())
                }

                SettingsSection(title: "Privacy") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("All scanning happens locally on your machine.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text("No data is ever transmitted outside of your computer.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }
            .padding(AppTheme.standardPadding)
        }
    }

    var scanningSettings: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.standardPadding) {
                SettingsSection(title: "Size Threshold") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Only show files larger than: \(Int(scanThreshold)) MB")
                            .font(.subheadline)

                        Slider(value: $scanThreshold, in: 10...1000, step: 10)

                        HStack {
                            Text("10 MB")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("1 GB")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                SettingsSection(title: "Excluded Locations") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("System-critical files are automatically excluded from deletion.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Button("Manage Exclusions...") {
                            // Would open exclusions management
                        }
                        .buttonStyle(.bordered)
                    }
                }

                SettingsSection(title: "Scan Performance") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Use multi-threaded scanning for faster results")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        HStack {
                            Text("⚡️ Fast")
                                .font(.caption)
                            Text("Scans common problem areas")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Text("🔍 Deep")
                                .font(.caption)
                            Text("Scans entire filesystem (slower)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()
            }
            .padding(AppTheme.standardPadding)
        }
    }

    var aboutSettings: some View {
        ScrollView {
            VStack(spacing: AppTheme.largePadding) {
                AppIcon(size: 80)

                Text("Hidden Bastard File Deleter")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Version 1.0.0")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Divider()

                VStack(alignment: .leading, spacing: AppTheme.standardPadding) {
                    Text("About")
                        .font(.headline)

                    Text("Hidden Bastard finds and removes hidden system files consuming excessive disk space. Reclaim your storage with a powerful, user-friendly interface.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(AppTheme.cornerRadius)

                VStack(spacing: 12) {
                    Link(destination: URL(string: "https://github.com/ghostintheprompt/hidden_bastard")!) {
                        HStack {
                            Image(systemName: "safari")
                            Text("View on GitHub")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(AppTheme.cornerRadius)
                    }
                    .buttonStyle(.plain)

                    Link(destination: URL(string: "https://github.com/ghostintheprompt/hidden_bastard/issues")!) {
                        HStack {
                            Image(systemName: "questionmark.circle")
                            Text("Support & Bug Reports")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(AppTheme.cornerRadius)
                    }
                    .buttonStyle(.plain)
                }

                Text("© 2025 Hidden Bastard. All rights reserved.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top)
            }
            .padding(AppTheme.largePadding)
        }
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)

            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(AppTheme.cornerRadius)
    }
}

struct SettingsTabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            .foregroundColor(isSelected ? .blue : .secondary)
            .cornerRadius(AppTheme.cornerRadius)
        }
        .buttonStyle(.plain)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
