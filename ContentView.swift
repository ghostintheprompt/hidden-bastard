import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var scanInProgress = false
    @State private var scanCompleted = false
    @State private var problemFiles: [ProblemFile] = []
    @State private var selectedCategories = Set<String>()
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
    
    // Categories of files to scan
    let categories = [
        "Apple Media Analysis", 
        "Incomplete Downloads",
        "Application Caches", 
        "Developer Files",
        "System Logs",
        "Docker",
        "Trash Items"
    ]
    
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
            // Set some default categories
            selectedCategories = ["Apple Media Analysis", "Incomplete Downloads", "Developer Files"].reduce(into: Set<String>()) { set, category in
                set.insert(category)
            }
            
            // Set up scanner delegate
            fileScanner.delegate = self
        }
    }
    
    var scanView: View {
        VStack(spacing: AppTheme.standardPadding) {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.smallPadding) {
                    // Category selection with icons
                    Text("Select Areas to Scan:")
                        .font(.headline)
                        .padding(.bottom, 5)
                    
                    VStack(spacing: 8) {
                        ForEach(categories, id: \.self) { category in
                            CategoryToggleRow(
                                icon: AppTheme.iconForCategory(category),
                                title: category,
                                isSelected: Binding(
                                    get: { selectedCategories.contains(category) },
                                    set: { newValue in
                                        if newValue {
                                            selectedCategories.insert(category)
                                        } else {
                                            selectedCategories.remove(category)
                                        }
                                    }
                                )
                            )
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
            .disabled(selectedCategories.isEmpty)
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
                                    EnhancedFileRowView(file: file, onDelete: {
                                        filesToDelete = [file]
                                        isShowingDeleteConfirmation = true
                                    })
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
                    // Show rule creation dialog
                }) {
                    Label("Add Rule", systemImage: "plus")
                }
                .buttonStyle(.borderless)
            }
            
            List {
                EnhancedRuleRowView(
                    name: "Media Analysis Prevention",
                    description: "Automatically clean Apple Media Analysis cache when it exceeds 1GB",
                    icon: "photo",
                    isEnabled: true,
                    schedule: "Daily"
                )
                
                EnhancedRuleRowView(
                    name: "Crashed Download Cleanup",
                    description: "Remove incomplete downloads older than 7 days",
                    icon: "arrow.down.circle",
                    isEnabled: false,
                    schedule: "Weekly"
                )
                
                EnhancedRuleRowView(
                    name: "Docker Cleanup",
                    description: "Remove unused Docker images and containers weekly",
                    icon: "cube.box",
                    isEnabled: true,
                    schedule: "Weekly"
                )
                
                EnhancedRuleRowView(
                    name: "System Log Rotation",
                    description: "Compress logs older than 30 days, delete after 90 days",
                    icon: "doc.text",
                    isEnabled: true,
                    schedule: "Monthly"
                )
                
                EnhancedRuleRowView(
                    name: "XCode Cache Management",
                    description: "Clean derived data folders not accessed in 30 days",
                    icon: "hammer",
                    isEnabled: true,
                    schedule: "Weekly"
                )
            }
            .listStyle(.inset)
        }
        .padding()
    }
    
    var systemMonitorView: View {
        VStack(spacing: AppTheme.standardPadding) {
            HStack {
                Text("System Monitoring")
                    .font(.headline)
                
                Spacer()
                
                // Refresh button
                Button(action: {
                    // Would refresh real-time data
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
                            .trim(from: 0, to: 0.7) // Would be calculated from actual disk usage
                            .stroke(Color.blue, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                            .frame(width: 100, height: 100)
                            .rotationEffect(.degrees(-90))
                        
                        VStack(spacing: 0) {
                            Text("70%")
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
                    
                    Text("213.7 GB free of 512 GB")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                
                // Problem areas chart
                VStack(alignment: .leading, spacing: 6) {
                    Text("Frequent Problem Areas")
                        .font(.headline)
                    
                    ForEach(["Apple Media Analysis", "Developer Files", "Application Caches"], id: \.self) { category in
                        HStack {
                            Text(category)
                                .font(.subheadline)
                            
                            Spacer()
                            
                            // This would be dynamic data in a real implementation
                            let value = category == "Apple Media Analysis" ? 0.8 : (category == "Developer Files" ? 0.6 : 0.4)
                            
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 6)
                                
                                Rectangle()
                                    .fill(AppTheme.colorForCategory(category))
                                    .frame(width: 200 * value, height: 6)
                            }
                            .frame(width: 200)
                            .clipShape(Capsule())
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
                Text("Space Usage Growth")
                    .font(.headline)
                
                HStack(alignment: .bottom, spacing: 12) {
                    ForEach(0..<7, id: \.self) { index in
                        let height = [0.3, 0.5, 0.35, 0.6, 0.45, 0.8, 0.7][index]
                        
                        VStack {
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [.blue, .purple]),
                                        startPoint: .bottom,
                                        endPoint: .top
                                    )
                                )
                                .frame(width: 30, height: 150 * height)
                                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                            
                            Text(["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][index])
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.top)
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
        
        // Start real scan using FileScanner
        fileScanner.startScan(categories: Array(selectedCategories))
    }
    
    // Delete confirmation handler
    func deleteConfirmedFiles() {
        // In a real app, we would use the FileScanner's deleteFile method
        // For files that require elevated permissions, we would use the RootHelper
        
        var deletedCount = 0
        var errorCount = 0
        
        for file in filesToDelete {
            if fileScanner.deleteFile(path: file.path) {
                deletedCount += 1
            } else {
                // Try with root privileges if normal deletion fails
                RootHelper.executeWithPrivileges(command: "rm -rf \"\(file.path)\"") { success in
                    if success {
                        deletedCount += 1
                    } else {
                        errorCount += 1
                    }
                }
            }
        }
        
        // Remove deleted files from the list
        problemFiles.removeAll { file in filesToDelete.contains { $0.id == file.id } }
        
        // Recalculate total size and disk space usage
        calculateTotalSize()
        diskSpaceUsage = calculateDiskSpaceUsage()
        
        // Show success toast
        isShowingDeletionSuccess = true
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
                    set: { _ in }
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

// Category toggle row with icon
struct CategoryToggleRow: View {
    let icon: String
    let title: String
    @Binding var isSelected: Bool
    
    var body: some View {
        Button(action: { isSelected.toggle() }) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(AppTheme.colorForCategory(title))
                    .frame(width: 24)
                
                Text(title)
                    .foregroundColor(.primary)
                
                Spacer()
                
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppTheme.colorForCategory(title), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppTheme.colorForCategory(title))
                            .frame(width: 24, height: 24)
                        
                        Image(systemName: "checkmark")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .fill(isSelected ? AppTheme.colorForCategory(title).opacity(0.1) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// Enhanced rule row view
struct EnhancedRuleRowView: View {
    let name: String
    let description: String
    let icon: String
    @State var isEnabled: Bool
    let schedule: String
    
    var body: some View {
        HStack(spacing: AppTheme.standardPadding) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .foregroundColor(.blue)
            }
            
            // Rule details
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.headline)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text(schedule)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(3)
                        .padding(.horizontal, 3)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                }
                .padding(.top, 2)
            }
            
            Spacer()
            
            // Toggle
            Toggle("", isOn: $isEnabled)
                .labelsHidden()
                .toggleStyle(CustomToggleStyle())
        }
        .padding(10)
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