import SwiftUI

// App-wide style definitions and assets
struct AppTheme {
    // Colors
    static let accent = Color("AccentColor")
    static let background = Color("BackgroundColor")
    static let secondaryBackground = Color("SecondaryBackgroundColor")
    static let text = Color("TextColor")
    static let secondaryText = Color("SecondaryTextColor")
    
    // Standard paddings
    static let standardPadding: CGFloat = 16
    static let smallPadding: CGFloat = 8
    static let largePadding: CGFloat = 24
    
    // Corner radius
    static let cornerRadius: CGFloat = 10
    
    // Animations
    static let standardAnimation = Animation.easeInOut(duration: 0.2)
    
    // Category colors
    static func colorForCategory(_ category: String) -> Color {
        switch category {
        case "Apple Media Analysis":
            return Color.blue
        case "Incomplete Downloads":
            return Color.orange
        case "Application Caches":
            return Color.purple
        case "Developer Files":
            return Color.green
        case "System Logs":
            return Color.yellow
        case "Docker":
            return Color.red
        case "Trash Items":
            return Color.gray
        default:
            return Color.teal
        }
    }
    
    // Category icons
    static func iconForCategory(_ category: String) -> String {
        switch category {
        case "Apple Media Analysis":
            return "photo"
        case "Incomplete Downloads":
            return "arrow.down.circle"
        case "Application Caches":
            return "folder"
        case "Developer Files":
            return "hammer"
        case "System Logs":
            return "doc.text"
        case "Docker":
            return "cube.box"
        case "Trash Items":
            return "trash"
        default:
            return "questionmark.circle"
        }
    }
}

// Custom button style
struct AccentButtonStyle: ButtonStyle {
    var isDestructive: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .fill(isDestructive ? Color.red : AppTheme.accent)
                    .opacity(configuration.isPressed ? 0.7 : 1.0)
            )
            .foregroundColor(.white)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// Custom toggle style
struct CustomToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer()
            RoundedRectangle(cornerRadius: 16)
                .fill(configuration.isOn ? AppTheme.accent : Color.gray.opacity(0.3))
                .frame(width: 50, height: 29)
                .overlay(
                    Circle()
                        .fill(Color.white)
                        .padding(2)
                        .offset(x: configuration.isOn ? 10 : -10)
                )
                .animation(AppTheme.standardAnimation, value: configuration.isOn)
                .onTapGesture {
                    withAnimation {
                        configuration.isOn.toggle()
                    }
                }
        }
    }
}

// App icon image
struct AppIcon: View {
    var size: CGFloat = 64
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.2)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.blue.opacity(0.8), Color.purple]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
            
            Image(systemName: "folder.badge.gearshape")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size * 0.5)
                .foregroundColor(.white)
                .offset(y: -2)
            
            Image(systemName: "magnifyingglass")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size * 0.25)
                .foregroundColor(.white)
                .offset(x: size * 0.25, y: size * 0.25)
        }
    }
}

// Loading indicator
struct LoadingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(AppTheme.accent, lineWidth: 3)
            .frame(width: 30, height: 30)
            .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
            .animation(
                Animation.linear(duration: 1)
                    .repeatForever(autoreverses: false),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

// Pulsing animation for the scan button
struct PulsingAnimation: ViewModifier {
    @State private var isPulsing = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.03 : 1.0)
            .animation(
                Animation.easeInOut(duration: 1.5)
                    .repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear {
                isPulsing = true
            }
    }
}

// GitHub README content
let gitHubReadmeContent = """
# Hidden Bastard File Deleter

<p align="center">
  <img src="screenshots/app_icon.png" width="128" height="128">
</p>

## Overview

Hidden Bastard File Deleter is a powerful macOS utility that finds and removes hidden system files consuming excessive disk space, with a clean modern interface and root access capabilities.

### Key Features

- **Deep System Scanning**: Find hidden files consuming your disk space
- **Smart Size Detection**: Identify abnormally large caches and temporary files
- **Media Analysis Prevention**: Stop Apple Media Analysis from taking over your drive
- **Incomplete Downloads**: Find and remove crashed download artifacts
- **Developer Tools**: Clean up XCode and iOS simulator data
- **Docker Cleanup**: Manage unused Docker images and containers
- **Root Access**: Safely remove protected system files with admin privileges

## Screenshots

<p align="center">
  <img src="screenshots/main_screen.png" width="800">
  <img src="screenshots/scan_results.png" width="800">
</p>

## Requirements

- macOS 11.0 or later
- Admin privileges for full functionality

## Installation

1. Download the latest release from the [Releases page](https://github.com/yourusername/HiddenBastardFileDeleter/releases)
2. Move to your Applications folder
3. Grant Full Disk Access in System Preferences > Security & Privacy > Privacy

## Development

Built with SwiftUI for modern macOS systems. To contribute:

1. Clone the repository
2. Open in Xcode 13 or later
3. Build and run

## License

MIT License. See LICENSE file for details.
"""

// Sample file type detection rules for different patterns
let filePatternRules = [
    // Incomplete downloads
    FilePatternRule(
        name: "Chrome Downloads",
        pattern: "\\.crdownload$",
        description: "Google Chrome partial downloads"
    ),
    FilePatternRule(
        name: "Safari Downloads", 
        pattern: "\\.download$", 
        description: "Safari partial downloads"
    ),
    FilePatternRule(
        name: "Firefox Downloads",
        pattern: "\\.part$",
        description: "Firefox partial downloads"
    ),
    
    // Temporary files
    FilePatternRule(
        name: "Temporary Files",
        pattern: "^~\\$|\\.(tmp|temp)$",
        description: "Temporary files"
    ),
    
    // Package manager caches
    FilePatternRule(
        name: "Node Modules",
        pattern: "node_modules$",
        description: "Node.js package cache folders"
    ),
    FilePatternRule(
        name: "Python Cache",
        pattern: "__pycache__$|\\.pyc$",
        description: "Python compiled cache files"
    ),
    
    // Log files
    FilePatternRule(
        name: "Log Files",
        pattern: "\\.log$|\\.log\\.[0-9]+$",
        description: "Application and system log files"
    )
]

// Rules for system path monitoring
struct FilePatternRule {
    let name: String
    let pattern: String
    let description: String
}