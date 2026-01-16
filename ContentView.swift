import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var locationManager = ScanLocationManager()
    @StateObject private var diskMonitor = DiskSpaceMonitor()
    @StateObject private var rulesEngine = RulesEngine()
    @State private var scanInProgress = false
    @State private var scanCompleted = false
    @State private var problemFiles: [ProblemFile] = []
    @State private var totalSizeFound: UInt64 = 0
    @State private var diskSpaceUsage: [DiskSpaceItem] = []
    @State private var isShowingSettings = false
    @State private var selectedTab = 0
    @State private var scanProgress: Float = 0
    @State private var showScanAnimation = false
    @State private var fileScanner = FileScanner()
    @State private var isShowingDeleteConfirmation = false
    @State private var filesToDelete: [ProblemFile] = []
    @State private var isShowingDeletionSuccess = false
    @State private var isShowingLocationPicker = false
    @State private var isShowingRuleEditor = false
    @State private var editingRule: CleaningRule?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with app icon and space usage visualization
                VStack {
                    HStack {
                        AppIcon(size: 42)
                            .padding(.trailing, 8)
                        
                        Text("Hidden Bastard File Deleter")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Button(action: {
                            isShowingSettings = true
                        }) {
                            Image(systemName: "gear")
                                .imageScale(.large)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.bottom, 8)
                    
                    // Space usage bar
                    if !diskSpaceUsage.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Space Wasted: \(formatBytes(totalSizeFound))")
                                .font(.headline)
                            
                            DiskUsageBar(items: diskSpaceUsage)
                                .frame(height: 24)
                                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                            
                            // Legend
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 4) {
                                ForEach(diskSpaceUsage) { item in
                                    HStack {
                                        Circle()
                                            .fill(item.color)
                                            .frame(width: 10, height: 10)
                                        Text(item.name)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(formatBytes(item.size))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(Color(NSColor.windowBackgroundColor))
                
                Divider()
                
                TabView(selection: $selectedTab) {
                    // Scan Tab
                    scanView
                        .tabItem {
                            Label("Scan", systemImage: "magnifyingglass")
                        }
                        .tag(0)
                    
                    // Files Tab
                    fileListView
                        .tabItem {
                            Label("Files", systemImage: "doc.text")
                        }
                        .tag(1)
                    
                    // Automated Rules Tab
                    rulesView
                        .tabItem {
                            Label("Rules", systemImage: "gear")
                        }
                        .tag(2)
                    
                    // System Monitor Tab
                    systemMonitorView
                        .tabItem {
                            Label("Monitor", systemImage: "chart.bar")
                        }
                        .tag(3)
                }
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView()
                    .preferredColorScheme(.dark)
            }
            .alert(isPresented: $isShowingDeleteConfirmation) {
                Alert(
                    title: Text("Delete Files"),
                    message: Text("Are you sure you want to delete \(filesToDelete.count) files? This will free \(formatBytes(filesToDelete.reduce(0) { $0 + $1.size })) of space."),
                    primaryButton: .destructive(Text("Delete")) {
                        deleteConfirmedFiles()
                    },
                    secondaryButton: .cancel()
                )
            }
            .toast(message: "Successfully deleted files!", isShowing: $isShowingDeletionSuccess, duration: 2.0)
        }
        .frame(minWidth: 800, minHeight: 600)
        .onAppear {
            // Set up scanner delegate
            fileScanner.delegate = self
        }
    }
    
    var scanView: View {
        VStack(spacing: AppTheme.standardPadding) {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.smallPadding) {
                    // Scan locations header
                    HStack {
                        Text("Scan Locations:")
                            .font(.headline)

                        Spacer()

                        Button(action: {
                            locationManager.addLocation(categories: ["Custom"]) { success in
                                if success {
                                    print("Location added successfully")
                                }
                            }
                        }) {
                            Label("Add Folder", systemImage: "plus.circle.fill")
                                .font(.subheadline)
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.bottom, 5)

                    // Scan locations list
                    if locationManager.scanLocations.isEmpty {
                        VStack(spacing: 12) {
                            Text("No scan locations added yet")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Text("Click 'Add Folder' to choose folders to scan")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    } else {
                        VStack(spacing: 8) {
                            ForEach(locationManager.scanLocations) { location in
                                ScanLocationRow(
                                    location: location,
                                    onToggle: {
                                        locationManager.toggleLocation(location)
                                    },
                                    onDelete: {
                                        if let index = locationManager.scanLocations.firstIndex(where: { $0.id == location.id }) {
                                            locationManager.removeLocation(at: IndexSet(integer: index))
                                        }
                                    }
                                )
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            
            Spacer()
            
            // Scan progress
            if scanInProgress {
                VStack(spacing: AppTheme.smallPadding) {
                    // Progress bar
                    ProgressView(value: scanProgress)
                        .progressViewStyle(.linear)
                        .padding(.horizontal)
                    
                    // Scanning animation
                    HStack(spacing: AppTheme.standardPadding) {
                        ZStack {
                            Circle()
                                .stroke(Color.blue.opacity(0.2), lineWidth: 4)
                                .frame(width: 60, height: 60)
                            
                            Circle()
                                .trim(from: 0, to: CGFloat(scanProgress))
                                .stroke(Color.blue, lineWidth: 4)
                                .frame(width: 60, height: 60)
                                .rotationEffect(.degrees(-90))
                                .animation(.linear, value: scanProgress)
                            
                            Image(systemName: "externaldrive.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)
                                .foregroundColor(.blue)
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Scanning your system...")
                                .font(.headline)
                            Text("Looking for hidden space-wasting files")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, AppTheme.standardPadding)
                }
            }
            
            // Scan button
            Button(action: {
                startScan()
            }) {
                HStack {
                    Image(systemName: scanInProgress ? "stop.circle" : "magnifyingglass")
                    Text(scanInProgress ? "Stop Scan" : "Start Deep Scan")
                        .fontWeight(.semibold)
                }
                .frame(minWidth: 200)
                .padding()
            }
            .buttonStyle(AccentButtonStyle())
            .disabled(locationManager.scanLocations.filter { $0.isEnabled }.isEmpty)
            .modifier(PulsingAnimation())
        }
        .padding()
    }
    
    var fileListView: View {
        VStack(spacing: 0) {
            // Empty state if no scan results yet
            if !scanCompleted || problemFiles.isEmpty {
                VStack(spacing: AppTheme.standardPadding) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60)
                        .foregroundColor(.secondary)
                    
                    Text("No Files Found")
                        .font(.headline)
                        .padding(.top)
                    
                    Text("Run a scan to find hidden files taking up space on your system")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Start Scan") {
                        selectedTab = 0 // Switch to scan tab
                    }
                    .buttonStyle(AccentButtonStyle())
                    .padding(.top)
                }
                .padding(AppTheme.largePadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // File list with expanded category sections
                List {
                    ForEach(groupedFiles.keys.sorted(), id: \.self) { category in
                        if let files = groupedFiles[category], !files.isEmpty {
                            Section(header: 
                                HStack {
                                    Image(systemName: AppTheme.iconForCategory(category))
                                        .foregroundColor(AppTheme.colorForCategory(category))
                                    Text(category)
                                    Spacer()
                                    Text("\(files.count) items · \(formatBytes(files.reduce(0) { $0 + $1.size }))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 6)
                            ) {
                                ForEach(files) { file in
                                    EnhancedFileRowView(
                                        file: file,
                                        onDelete: {
                                            filesToDelete = [file]
                                            isShowingDeleteConfirmation = true
                                        },
                                        onToggle: { newValue in
                                            if let index = problemFiles.firstIndex(where: { $0.id == file.id }) {
                                                problemFiles[index].isSelected = newValue
                                            }
                                        }
                                    )
                                }
                            }
                        }
                    }
                }
                .listStyle(.inset)
                
                // Bottom toolbar
                VStack(spacing: 0) {
                    Divider()
                    
                    HStack {
                        HStack {
                            Button("Select All") {
                                problemFiles = problemFiles.map { file in
                                    var newFile = file
                                    newFile.isSelected = true
                                    return newFile
                                }
                            }
                            .buttonStyle(.borderless)
                            
                            Button("Select None") {
                                problemFiles = problemFiles.map { file in
                                    var newFile = file
                                    newFile.isSelected = false
                                    return newFile
                                }
                            }
                            .buttonStyle(.borderless)
                        }
                        .controlSize(.small)
                        
                        Spacer()
                        
                        Text("Selected: \(formatBytes(selectedSize))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Button("Delete Selected") {
                            let selectedFiles = problemFiles.filter { $0.isSelected }
                            if !selectedFiles.isEmpty {
                                filesToDelete = selectedFiles
                                isShowingDeleteConfirmation = true
                            }
                        }
                        .buttonStyle(AccentButtonStyle(isDestructive: true))
                        .disabled(problemFiles.filter { $0.isSelected }.isEmpty)
                    }
                    .padding()
                }
            }
        }
    }
    
    var rulesView: View {
        VStack(spacing: AppTheme.standardPadding) {
            HStack {
                Text("Automated Cleaning Rules")
                    .font(.headline)

                Spacer()

                Button(action: {
                    editingRule = nil
                    isShowingRuleEditor = true
                }) {
                    Label("Add Rule", systemImage: "plus")
                }
                .buttonStyle(.borderless)
            }

            if rulesEngine.rules.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.2.circlepath")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)

                    Text("No Automated Rules")
                        .font(.headline)

                    Text("Create rules to automatically clean up files on a schedule")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Button("Create Your First Rule") {
                        editingRule = nil
                        isShowingRuleEditor = true
                    }
                    .buttonStyle(AccentButtonStyle())
                    .padding(.top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(rulesEngine.rules) { rule in
                        RealRuleRowView(
                            rule: rule,
                            onToggle: {
                                rulesEngine.toggleRule(rule)
                            },
                            onEdit: {
                                editingRule = rule
                                isShowingRuleEditor = true
                            },
                            onExecute: {
                                rulesEngine.executeRule(rule) { result in
                                    print("Rule executed: \(result.filesProcessed) files, \(result.spaceFreed) bytes freed")
                                    if result.wasSuccessful {
                                        isShowingDeletionSuccess = true
                                    }
                                }
                            }
                        )
                    }
                    .onDelete { offsets in
                        rulesEngine.deleteRule(at: offsets)
                    }
                }
                .listStyle(.inset)
            }
        }
        .padding()
        .sheet(isPresented: $isShowingRuleEditor) {
            RuleEditorView(
                rule: editingRule,
                onSave: { newRule in
                    if let existingRule = editingRule {
                        rulesEngine.updateRule(newRule)
                    } else {
                        rulesEngine.addRule(newRule)
                    }
                    isShowingRuleEditor = false
                },
                onCancel: {
                    isShowingRuleEditor = false
                }
            )
        }
    }
    
    var systemMonitorView: View {
        VStack(spacing: AppTheme.standardPadding) {
            HStack {
                Text("System Monitoring")
                    .font(.headline)

                Spacer()

                // Refresh button
                Button(action: {
                    diskMonitor.refresh()
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
            }

            HStack(spacing: AppTheme.standardPadding) {
                // Disk space donut chart
                VStack {
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 10)
                            .frame(width: 100, height: 100)

                        Circle()
                            .trim(from: 0, to: diskMonitor.usagePercentage)
                            .stroke(
                                diskMonitor.usagePercentage > 0.9 ? Color.red :
                                    diskMonitor.usagePercentage > 0.75 ? Color.orange : Color.blue,
                                style: StrokeStyle(lineWidth: 10, lineCap: .round)
                            )
                            .frame(width: 100, height: 100)
                            .rotationEffect(.degrees(-90))

                        VStack(spacing: 0) {
                            Text("\(Int(diskMonitor.usagePercentage * 100))%")
                                .font(.title3)
                                .fontWeight(.semibold)
                            Text("Used")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Text("Disk Space")
                        .font(.headline)
                        .padding(.top, 4)

                    Text("\(diskMonitor.formatBytes(diskMonitor.freeSpace)) free of \(diskMonitor.formatBytes(diskMonitor.totalSpace))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                
                // Problem areas chart
                VStack(alignment: .leading, spacing: 6) {
                    Text("Problem Areas Found")
                        .font(.headline)

                    if diskSpaceUsage.isEmpty {
                        Text("Run a scan to see problem areas")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(diskSpaceUsage.prefix(3)) { item in
                            HStack {
                                Text(item.name)
                                    .font(.subheadline)

                                Spacer()

                                ZStack(alignment: .leading) {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(height: 6)

                                    Rectangle()
                                        .fill(item.color)
                                        .frame(width: 200 * item.percentage, height: 6)
                                }
                                .frame(width: 200)
                                .clipShape(Capsule())

                                Text(formatBytes(item.size))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(width: 70, alignment: .trailing)
                            }
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            }
            
            // Growth over time chart
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Disk Usage (Last 7 Days)")
                        .font(.headline)

                    Spacer()

                    // Usage trend indicator
                    HStack(spacing: 4) {
                        Image(systemName: diskMonitor.getUsageTrend().icon)
                            .foregroundColor(diskMonitor.getUsageTrend().color)
                        Text(diskMonitor.getUsageTrend().description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                let weekHistory = diskMonitor.getHistoryForDays(7)

                if weekHistory.isEmpty {
                    Text("No historical data available yet")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                } else {
                    HStack(alignment: .bottom, spacing: 12) {
                        ForEach(Array(weekHistory.enumerated()), id: \.offset) { index, snapshot in
                            let maxUsage = weekHistory.map { $0.usagePercentage }.max() ?? 1.0
                            let normalizedHeight = maxUsage > 0 ? snapshot.usagePercentage / maxUsage : 0

                            VStack {
                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [.blue, .purple]),
                                            startPoint: .bottom,
                                            endPoint: .top
                                        )
                                    )
                                    .frame(width: 30, height: 150 * normalizedHeight)
                                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))

                                Text(dayLabel(for: snapshot.date))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.top)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            
            Spacer()
        }
        .padding()
    }
    
    // Group files by category
    var groupedFiles: [String: [ProblemFile]] {
        Dictionary(grouping: problemFiles) { $0.category }
    }
    
    // Calculate size of selected files
    var selectedSize: UInt64 {
        problemFiles.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
    }
    
    // Start scanning for files
    func startScan() {
        if scanInProgress {
            // Cancel scan
            fileScanner.cancelScan()
            scanInProgress = false
            return
        }

        scanInProgress = true
        scanCompleted = false
        problemFiles = []
        scanProgress = 0
        showScanAnimation = true

        // Start real scan using FileScanner with selected locations
        fileScanner.startScan(locations: locationManager.scanLocations, locationManager: locationManager)
    }
    
    // Delete confirmation handler
    func deleteConfirmedFiles() {
        var deletedFiles: [UUID] = []

        for file in filesToDelete {
            if fileScanner.deleteFile(path: file.path) {
                deletedFiles.append(file.id)
            }
        }

        // Remove deleted files from the list
        problemFiles.removeAll { file in deletedFiles.contains(file.id) }

        // Recalculate total size and disk space usage
        calculateTotalSize()
        diskSpaceUsage = calculateDiskSpaceUsage()

        // Show success toast if any files were deleted
        if !deletedFiles.isEmpty {
            isShowingDeletionSuccess = true
        }
    }
    
    func calculateTotalSize() {
        totalSizeFound = problemFiles.reduce(0) { $0 + $1.size }
    }
    
    func calculateDiskSpaceUsage() -> [DiskSpaceItem] {
        var result: [DiskSpaceItem] = []
        
        // Group sizes by category
        var sizeByCategory: [String: UInt64] = [:]
        for file in problemFiles {
            sizeByCategory[file.category, default: 0] += file.size
        }
        
        // Create items with calculated percentages
        let total = sizeByCategory.values.reduce(0, +)
        for (category, size) in sizeByCategory {
            result.append(DiskSpaceItem(
                name: category,
                size: size,
                percentage: total > 0 ? Double(size) / Double(total) : 0,
                color: AppTheme.colorForCategory(category)
            ))
        }
        
        return result.sorted { $0.size > $1.size }
    }
    
    func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }

    func dayLabel(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yest"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE"
            return formatter.string(from: date)
        }
    }
}

// Extension for the FileScannerDelegate protocol
extension ContentView: FileScannerDelegate {
    func scannerDidStartScan() {
        DispatchQueue.main.async {
            self.scanInProgress = true
            self.problemFiles = []
        }
    }
    
    func scannerDidUpdateProgress(progress: Float) {
        DispatchQueue.main.async {
            self.scanProgress = progress
        }
    }
    
    func scannerDidFinishScan(files: [ProblemFile]) {
        DispatchQueue.main.async {
            self.problemFiles = files
            self.diskSpaceUsage = self.calculateDiskSpaceUsage()
            self.calculateTotalSize()
            self.scanInProgress = false
            self.scanCompleted = true
            
            // Switch to Files tab if files were found
            if !files.isEmpty {
                self.selectedTab = 1
            }
        }
    }
}

// Enhanced file row view with more details and better styling
struct EnhancedFileRowView: View {
    let file: ProblemFile
    let onDelete: () -> Void
    let onToggle: (Bool) -> Void
    @State private var isHovered = false
    @State private var showPreview = false
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                // File icon based on type
                FileIconView(path: file.path)
                    .frame(width: 32, height: 32)
                
                // File details
                VStack(alignment: .leading, spacing: 2) {
                    Text(file.name)
                        .font(.headline)
                    
                    Text(file.path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // File size and date
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatBytes(file.size))
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(formatDate(file.dateModified))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                
                // Risk level indicator
                RiskLevelBadge(level: file.riskLevel)
                    .padding(.horizontal, 8)
                
                // Selection toggle
                Toggle("", isOn: Binding(
                    get: { file.isSelected },
                    set: { newValue in onToggle(newValue) }
                ))
                .labelsHidden()
                
                // Delete button
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .opacity(isHovered ? 1.0 : 0.6)
                }
                .buttonStyle(.plain)
                .padding(.leading, 4)
            }
            .padding(8)
            .contentShape(Rectangle())
            .background(isHovered ? Color.gray.opacity(0.1) : Color.clear)
            .cornerRadius(AppTheme.cornerRadius)
            .onHover { hovering in
                isHovered = hovering
            }
        }
    }
    
    func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// File icon view that shows different icons based on file type
struct FileIconView: View {
    let path: String
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(iconColor)
                .frame(width: 32, height: 32)
            
            Image(systemName: iconName)
                .font(.system(size: 16))
                .foregroundColor(.white)
        }
    }
    
    var iconName: String {
        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
        
        if ext.isEmpty {
            return "folder"
        }
        
        switch ext {
        case "pdf":
            return "doc.text"
        case "jpg", "jpeg", "png", "gif", "heic":
            return "photo"
        case "mov", "mp4":
            return "film"
        case "mp3", "wav", "m4a":
            return "music.note"
        case "zip", "gz", "tar", "7z":
            return "archivebox"
        case "app":
            return "app.dashed"
        case "download", "part", "crdownload":
            return "arrow.down.circle"
        case "log":
            return "text.alignleft"
        default:
            return "doc"
        }
    }
    
    var iconColor: Color {
        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
        
        switch ext {
        case "pdf":
            return .red
        case "jpg", "jpeg", "png", "gif", "heic":
            return .blue
        case "mov", "mp4":
            return .purple
        case "mp3", "wav", "m4a":
            return .pink
        case "zip", "gz", "tar", "7z":
            return .brown
        case "app":
            return .indigo
        case "download", "part", "crdownload":
            return .orange
        case "log":
            return .gray
        default:
            return .cyan
        }
    }
}

// Risk level badge
struct RiskLevelBadge: View {
    let level: RiskLevel
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(level.color)
                .frame(width: 8, height: 8)
            
            Text(level.rawValue)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(level.color.opacity(0.1))
        .cornerRadius(10)
    }
}

// Scan location row
struct ScanLocationRow: View {
    let location: ScanLocation
    let onToggle: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack {
            // Folder icon
            Image(systemName: "folder.fill")
                .foregroundColor(.blue)
                .frame(width: 24)

            // Location info
            VStack(alignment: .leading, spacing: 2) {
                Text(location.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(location.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Categories badge
            if !location.categories.isEmpty {
                Text(location.categories.joined(separator: ", "))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(4)
            }

            // Toggle
            Toggle("", isOn: Binding(
                get: { location.isEnabled },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
            .toggleStyle(CustomToggleStyle())

            // Delete button
            if isHovered {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                .fill(location.isEnabled ? Color.blue.opacity(0.05) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// Real rule row view
struct RealRuleRowView: View {
    let rule: CleaningRule
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onExecute: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: AppTheme.standardPadding) {
            // Icon
            ZStack {
                Circle()
                    .fill(rule.isEnabled ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                    .frame(width: 36, height: 36)

                Image(systemName: rule.icon)
                    .foregroundColor(rule.isEnabled ? .blue : .secondary)
            }

            // Rule details
            VStack(alignment: .leading, spacing: 2) {
                Text(rule.name)
                    .font(.headline)
                    .foregroundColor(rule.isEnabled ? .primary : .secondary)

                Text(rule.description)
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    // Schedule badge
                    Text(rule.schedule.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(3)
                        .padding(.horizontal, 3)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)

                    // Last run info
                    if let lastRun = rule.lastRun {
                        Text("Last run: \(timeAgo(lastRun))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Never run")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 2)
            }

            Spacer()

            // Action buttons (show on hover)
            if isHovered {
                HStack(spacing: 8) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)

                    if rule.schedule == .manual {
                        Button(action: onExecute) {
                            Image(systemName: "play.fill")
                                .foregroundColor(.green)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Toggle
            Toggle("", isOn: Binding(
                get: { rule.isEnabled },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
            .toggleStyle(CustomToggleStyle())
        }
        .padding(10)
        .background(rule.isEnabled ? Color.blue.opacity(0.02) : Color.clear)
        .cornerRadius(AppTheme.cornerRadius)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// Fancy disk usage bar
struct DiskUsageBar: View {
    let items: [DiskSpaceItem]
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                ForEach(items) { item in
                    if item.percentage > 0 {
                        Rectangle()
                            .fill(item.color)
                            .frame(width: max(1, CGFloat(item.percentage) * geometry.size.width - 2))
                    }
                }
            }
        }
    }
}

// Toast notification
struct ToastView: ViewModifier {
    @Binding var isShowing: Bool
    let message: String
    let duration: Double
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            if isShowing {
                VStack {
                    Spacer()
                    
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(message)
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(AppTheme.cornerRadius)
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                            withAnimation {
                                isShowing = false
                            }
                        }
                    }
                }
            }
        }
        .animation(.easeInOut, value: isShowing)
    }
}

extension View {
    func toast(message: String, isShowing: Binding<Bool>, duration: Double) -> some View {
        self.modifier(ToastView(isShowing: isShowing, message: message, duration: duration))
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}