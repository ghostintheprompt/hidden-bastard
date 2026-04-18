import SwiftUI

struct ContentView: View {
    @StateObject private var state = AppState()
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack {
            AppTheme.backgroundColor.ignoresSafeArea()
            
            // Background grid aesthetic
            GridView()
                .opacity(0.15)
            
            HStack(spacing: 0) {
                // Sidebar
                Sidebar(selectedTab: $selectedTab)
                    .frame(width: 220)
                    .background(Color(red: 14/255, green: 14/255, blue: 20/255))
                
                // Main Content
                VStack(spacing: 0) {
                    HeaderView(state: state)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                    
                    Divider()
                        .background(AppTheme.primaryColor.opacity(0.3))
                    
                    ZStack {
                        if selectedTab == 0 {
                            DashboardView(state: state)
                        } else if selectedTab == 1 {
                            FileListView(state: state)
                        } else if selectedTab == 2 {
                            RulesListView(rulesEngine: state.rulesEngine)
                        } else {
                            SettingsView()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .environmentObject(state)
        .onAppear {
            state.diskMonitor.refresh()
        }
        .frame(minWidth: 900, minHeight: 600)
    }
}

struct DashboardView: View {
    @ObservedObject var state: AppState
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Disk Visualization
                DiskUsageSection(monitor: state.diskMonitor)
                
                // Scan Trigger
                ScanSection(state: state)
                
                // Quick Actions
                QuickActionsSection(state: state)
                
                Spacer()
            }
            .padding(24)
        }
    }
}

struct DiskUsageSection: View {
    @ObservedObject var monitor: DiskSpaceMonitor
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("DISK ARCHITECTURE")
                .font(.system(.headline, design: .monospaced))
                .foregroundColor(AppTheme.primaryColor)
            
            VStack(spacing: 12) {
                // Segmented Bar Chart
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        // Used Space
                        Rectangle()
                            .fill(AppTheme.primaryColor)
                            .frame(width: geo.size.width * CGFloat(monitor.usagePercentage))
                        
                        // Free Space
                        Rectangle()
                            .fill(AppTheme.neutralColor.opacity(0.3))
                    }
                }
                .frame(height: 24)
                .overlay(
                    Rectangle()
                        .stroke(AppTheme.primaryColor, lineWidth: 1)
                )
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("USED")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(AppTheme.neutralColor)
                        Text(monitor.formatBytes(monitor.usedSpace))
                            .font(.system(.title3, design: .monospaced))
                            .foregroundColor(AppTheme.primaryColor)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("FREE")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(AppTheme.neutralColor)
                        Text(monitor.formatBytes(monitor.freeSpace))
                            .font(.system(.title3, design: .monospaced))
                            .foregroundColor(AppTheme.neutralColor)
                    }
                }
            }
            .padding(20)
            .background(AppTheme.surfaceColor)
            .border(AppTheme.primaryColor.opacity(0.3), width: 1)
        }
    }
}

struct ScanSection: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SYSTEM ANALYSIS")
                .font(.system(.headline, design: .monospaced))
                .foregroundColor(AppTheme.primaryColor)

            Button(action: {
                if state.isScanning {
                    state.cancelScan()
                } else {
                    state.startScan()
                }
            }) {
                HStack {
                    Image(systemName: state.isScanning ? "stop.fill" : "magnifyingglass")
                    Text(state.isScanning ? "CANCEL SCAN" : "INITIALIZE SCAN")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(AccentButtonStyle(isDestructive: state.isScanning))

            if state.isScanning {
                ProgressView(value: state.scanProgress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .tint(AppTheme.primaryColor)
            }

            if !state.scanStatus.isEmpty {
                Text(state.scanStatus)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(state.isScanning ? AppTheme.warningColor : AppTheme.successColor)
            }

            if !state.scanLog.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(state.scanLog, id: \.self) { line in
                            Text(line)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(AppTheme.neutralColor)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(8)
                }
                .frame(maxHeight: 120)
                .background(Color.black.opacity(0.4))
                .overlay(Rectangle().stroke(AppTheme.primaryColor.opacity(0.2), lineWidth: 1))
            }
        }
    }
}

struct QuickActionsSection: View {
    @ObservedObject var state: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("AUTOMATED PROTOCOLS")
                .font(.system(.headline, design: .monospaced))
                .foregroundColor(AppTheme.primaryColor)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(state.rulesEngine.rules) { rule in
                    RuleQuickActionCard(rule: rule, engine: state.rulesEngine)
                }
            }
        }
    }
}

struct RuleQuickActionCard: View {
    let rule: CleaningRule
    let engine: RulesEngine
    @State private var isExecuting = false
    
    var body: some View {
        Button(action: {
            isExecuting = true
            engine.executeRule(rule) { _ in
                isExecuting = false
            }
        }) {
            HStack {
                Image(systemName: rule.icon)
                    .font(.title2)
                VStack(alignment: .leading) {
                    Text(rule.name.uppercased())
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.bold)
                    Text(isExecuting ? "EXECUTING..." : "RUN PROTOCOL")
                        .font(.system(.caption2, design: .monospaced))
                        .opacity(0.7)
                }
                Spacer()
            }
            .padding(12)
            .background(AppTheme.surfaceColor)
            .border(AppTheme.primaryColor.opacity(0.3), width: 1)
            .foregroundColor(AppTheme.primaryColor)
        }
        .buttonStyle(.plain)
    }
}

struct HeaderView: View {
    @ObservedObject var state: AppState
    
    var body: some View {
        HStack {
            AppIcon(size: 40)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("HIDDEN BASTARD")
                    .font(.system(.title3, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.primaryColor)
                
                Text("V 2.0 // SYSTEM MAINTENANCE ACTIVE")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(AppTheme.successColor)
            }
            
            Spacer()
            
            if !state.problemFiles.isEmpty {
                Button("PURGE SELECTED (\(ByteCountFormatter.string(fromByteCount: Int64(state.totalSelectedSize), countStyle: .file)))") {
                    state.deleteSelectedFiles()
                }
                .buttonStyle(AccentButtonStyle(isDestructive: true))
            }
        }
    }
}

struct Sidebar: View {
    @Binding var selectedTab: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Spacer().frame(height: 20)
            
            SidebarItem(icon: "chart.bar.xaxis", title: "DASHBOARD", isSelected: selectedTab == 0) { selectedTab = 0 }
            SidebarItem(icon: "list.bullet.rectangle", title: "DETECTION LOG", isSelected: selectedTab == 1) { selectedTab = 1 }
            SidebarItem(icon: "bolt.shield", title: "CLEANING RULES", isSelected: selectedTab == 2) { selectedTab = 2 }
            SidebarItem(icon: "gearshape", title: "CONFIGURATION", isSelected: selectedTab == 3) { selectedTab = 3 }
            
            Spacer()
            
            // System Status info
            VStack(alignment: .leading, spacing: 4) {
                Text("LINK STATUS: STABLE")
                    .font(.system(size: 9, design: .monospaced))
                Text("ENCRYPTION: AES-256")
                    .font(.system(size: 9, design: .monospaced))
            }
            .foregroundColor(AppTheme.successColor)
            .padding(16)
            .opacity(0.6)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(red: 14/255, green: 14/255, blue: 20/255))
        .colorScheme(.dark)
    }
}

struct SidebarItem: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .frame(width: 20)
                Text(title)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(isSelected ? .bold : .regular)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isSelected ? AppTheme.primaryColor.opacity(0.15) : Color.clear)
            .foregroundColor(isSelected ? AppTheme.primaryColor : AppTheme.neutralColor)
            .overlay(
                isSelected ? Rectangle().frame(width: 3).foregroundColor(AppTheme.primaryColor) : nil,
                alignment: .leading
            )
        }
        .buttonStyle(.plain)
    }
}

struct GridView: View {
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 30
            for x in stride(from: 0, through: size.width, by: step) {
                context.stroke(Path { p in
                    p.move(to: CGPoint(x: x, y: 0))
                    p.addLine(to: CGPoint(x: x, y: size.height))
                }, with: .color(AppTheme.primaryColor.opacity(0.2)), lineWidth: 0.5)
            }
            for y in stride(from: 0, through: size.height, by: step) {
                context.stroke(Path { p in
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: size.width, y: y))
                }, with: .color(AppTheme.primaryColor.opacity(0.2)), lineWidth: 0.5)
            }
        }
    }
}

// Placeholder View for Detection Log
struct FileListView: View {
    @ObservedObject var state: AppState
    
    var body: some View {
        VStack {
            if state.problemFiles.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "shield.check")
                        .font(.system(size: 60))
                        .foregroundColor(AppTheme.successColor)
                    Text("NO THREATS DETECTED")
                        .font(.system(.title2, design: .monospaced))
                }
                .opacity(0.5)
            } else {
                List {
                    ForEach(state.problemFiles) { file in
                        HStack {
                            Toggle("", isOn: Binding(
                                get: { state.selectedFileIds.contains(file.id) },
                                set: { isOn in
                                    if isOn {
                                        state.selectedFileIds.insert(file.id)
                                    } else {
                                        state.selectedFileIds.remove(file.id)
                                    }
                                }
                            ))
                            .toggleStyle(CheckboxToggleStyle())
                            
                            VStack(alignment: .leading) {
                                Text(file.name)
                                    .font(.system(.body, design: .monospaced))
                                Text(file.path)
                                    .font(.system(.caption, design: .monospaced))
                                    .opacity(0.5)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            Text(file.formattedSize)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(AppTheme.primaryColor)
                        }
                        .listRowBackground(Color.clear)
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.plain)
            }
        }
        .padding(24)
    }
}

struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: { configuration.isOn.toggle() }) {
            Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                .foregroundColor(configuration.isOn ? AppTheme.primaryColor : .gray)
                .font(.title3)
        }
        .buttonStyle(.plain)
    }
}
