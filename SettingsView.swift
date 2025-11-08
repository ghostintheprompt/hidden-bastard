import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("autoScanOnLaunch") private var autoScanOnLaunch = false
    @AppStorage("showNotifications") private var showNotifications = true
    @AppStorage("minimizeToMenuBar") private var minimizeToMenuBar = false
    @AppStorage("darkModeOverride") private var darkModeOverride = false
    @AppStorage("scanThreshold") private var scanThreshold = 100.0 // MB
    @AppStorage("licenseKey") private var licenseKey = ""
    @AppStorage("isLicensed") private var isLicensed = false

    @State private var selectedTab = 0
    @State private var showLicenseSuccess = false
    @State private var licenseError = ""

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
                    title: "License",
                    icon: "key.fill",
                    isSelected: selectedTab == 2,
                    action: { selectedTab = 2 }
                )

                SettingsTabButton(
                    title: "About",
                    icon: "info.circle",
                    isSelected: selectedTab == 3,
                    action: { selectedTab = 3 }
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

                licenseSettings
                    .tag(2)

                aboutSettings
                    .tag(3)
            }
            .tabViewStyle(.automatic)
        }
        .frame(width: 600, height: 500)
    }

    var generalSettings: View {
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

    var scanningSettings: View {
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

    var licenseSettings: View {
        ScrollView {
            VStack(spacing: AppTheme.largePadding) {
                if isLicensed {
                    // Licensed state
                    VStack(spacing: AppTheme.standardPadding) {
                        ZStack {
                            Circle()
                                .fill(Color.green.opacity(0.1))
                                .frame(width: 80, height: 80)

                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.green)
                        }

                        Text("Licensed")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("Thank you for supporting Hidden Bastard!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        Divider()
                            .padding(.vertical, 8)

                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("License Key:")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(licenseKey.isEmpty ? "N/A" : "••••-••••-••••")
                                    .font(.system(.body, design: .monospaced))
                            }

                            HStack {
                                Text("Status:")
                                    .foregroundColor(.secondary)
                                Spacer()
                                HStack {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 8, height: 8)
                                    Text("Active")
                                        .foregroundColor(.green)
                                }
                            }
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(AppTheme.cornerRadius)

                        Button("Deactivate License") {
                            isLicensed = false
                            licenseKey = ""
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.red)
                    }
                } else {
                    // Trial/unlicensed state
                    VStack(spacing: AppTheme.standardPadding) {
                        AppIcon(size: 64)

                        Text("Hidden Bastard")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("Trial Version")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(12)

                        VStack(alignment: .leading, spacing: 8) {
                            FeatureRow(icon: "checkmark.circle.fill", text: "Scan all file categories", isIncluded: true)
                            FeatureRow(icon: "checkmark.circle.fill", text: "Delete up to 10GB per session", isIncluded: true)
                            FeatureRow(icon: "xmark.circle.fill", text: "Unlimited deletions", isIncluded: false)
                            FeatureRow(icon: "xmark.circle.fill", text: "Automated cleaning rules", isIncluded: false)
                            FeatureRow(icon: "xmark.circle.fill", text: "Priority support", isIncluded: false)
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(AppTheme.cornerRadius)

                        Divider()

                        VStack(spacing: 12) {
                            Text("Enter License Key")
                                .font(.headline)

                            TextField("XXXX-XXXX-XXXX-XXXX", text: $licenseKey)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                                .multilineTextAlignment(.center)

                            if !licenseError.isEmpty {
                                Text(licenseError)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }

                            Button("Activate License") {
                                validateLicense()
                            }
                            .buttonStyle(AccentButtonStyle())
                            .disabled(licenseKey.isEmpty)

                            Button("Purchase License ($19.99)") {
                                // Would open purchase page
                                NSWorkspace.shared.open(URL(string: "https://example.com/purchase")!)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
            .padding(AppTheme.largePadding)
            .frame(maxWidth: .infinity)
        }
    }

    var aboutSettings: View {
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
                    Link(destination: URL(string: "https://github.com")!) {
                        HStack {
                            Image(systemName: "safari")
                            Text("Visit Website")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(AppTheme.cornerRadius)
                    }
                    .buttonStyle(.plain)

                    Link(destination: URL(string: "https://github.com")!) {
                        HStack {
                            Image(systemName: "questionmark.circle")
                            Text("Support & Documentation")
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

    func validateLicense() {
        // Simple validation - in a real app, this would verify against a server or use cryptographic validation
        let validPrefixes = ["HBFD", "TEST", "DEMO"]
        let hasValidPrefix = validPrefixes.contains { licenseKey.uppercased().hasPrefix($0) }

        if licenseKey.count >= 12 && hasValidPrefix {
            isLicensed = true
            licenseError = ""
            showLicenseSuccess = true
        } else {
            licenseError = "Invalid license key. Please check and try again."
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

struct FeatureRow: View {
    let icon: String
    let text: String
    let isIncluded: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(isIncluded ? .green : .secondary)
            Text(text)
                .font(.subheadline)
                .foregroundColor(isIncluded ? .primary : .secondary)
            Spacer()
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
