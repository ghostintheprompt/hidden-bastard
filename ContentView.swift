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
                            DeletionHistoryView(state: state)
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
        .onChange(of: state.isScanning) { scanning in
            if !scanning && !state.problemFiles.isEmpty {
                selectedTab = 1
            }
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
                
                Text(state.isScanning ? "SCANNING..." : "V 1.0 // READY")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(state.isScanning ? AppTheme.warningColor : AppTheme.successColor)
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
            SidebarItem(icon: "list.bullet.rectangle", title: "FOUND FILES", isSelected: selectedTab == 1) { selectedTab = 1 }
            SidebarItem(icon: "clock.arrow.circlepath", title: "HISTORY", isSelected: selectedTab == 2) { selectedTab = 2 }
            SidebarItem(icon: "gearshape", title: "SETTINGS", isSelected: selectedTab == 3) { selectedTab = 3 }
            
            Spacer()
            
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
        VStack(spacing: 0) {
            if !state.problemFiles.isEmpty {
                HStack {
                    Text("\(state.problemFiles.count) ITEMS — \(ByteCountFormatter.string(fromByteCount: Int64(state.problemFiles.reduce(0) { $0 + $1.size }), countStyle: .file))")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(AppTheme.neutralColor)
                    Spacer()
                    Button("SELECT ALL") { state.selectAll() }
                        .buttonStyle(.plain)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(AppTheme.primaryColor)
                    Text("·").foregroundColor(AppTheme.neutralColor)
                    Button("NONE") { state.selectNone() }
                        .buttonStyle(.plain)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(AppTheme.neutralColor)
                    if !state.selectedFileIds.isEmpty {
                        Button("MOVE TO TRASH (\(ByteCountFormatter.string(fromByteCount: Int64(state.totalSelectedSize), countStyle: .file)))") {
                            state.deleteSelectedFiles()
                        }
                        .buttonStyle(AccentButtonStyle(isDestructive: true))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(AppTheme.surfaceColor)
            }
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
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(file.name)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(.white)
                                Text(file.path)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(AppTheme.neutralColor)
                                    .lineLimit(1)
                                let info = CategoryInfo.for_(file.category)
                                Text("\(info.emoji) \(info.plain)")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(AppTheme.warningColor.opacity(0.8))
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
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
    }
}

struct DeletionHistoryView: View {
    @ObservedObject var state: AppState

    var totalFreed: UInt64 {
        state.deletionHistory.reduce(0) { $0 + $1.size }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("DELETION HISTORY")
                        .font(.system(.headline, design: .monospaced))
                        .foregroundColor(AppTheme.primaryColor)
                    Text("TOTAL FREED: \(ByteCountFormatter.string(fromByteCount: Int64(totalFreed), countStyle: .file))")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(AppTheme.successColor)
                }
                Spacer()
                if !state.deletionHistory.isEmpty {
                    Button("CLEAR HISTORY") { state.clearDeletionHistory() }
                        .buttonStyle(.plain)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(AppTheme.dangerColor)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(AppTheme.surfaceColor)

            if state.deletionHistory.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 48))
                        .foregroundColor(AppTheme.primaryColor.opacity(0.4))
                    Text("NO DELETIONS YET")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(AppTheme.neutralColor)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(state.deletionHistory) { record in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(record.name)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(.white)
                                Text(record.path)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(AppTheme.neutralColor)
                                    .lineLimit(1)
                                Text(record.formattedDate)
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundColor(AppTheme.neutralColor.opacity(0.6))
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(record.formattedSize)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(AppTheme.primaryColor)
                                Text(record.category.uppercased())
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundColor(AppTheme.neutralColor)
                            }
                        }
                        .listRowBackground(Color.clear)
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.plain)
            }
        }
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
