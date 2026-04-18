import SwiftUI
import AppKit

struct AppTheme {
    // Standard spacing and dimensions
    static let cornerRadius: CGFloat = 8 // Slightly rounded for modern feel
    static let largeCornerRadius: CGFloat = 12
    static let standardPadding: CGFloat = 12
    static let smallPadding: CGFloat = 6
    static let largePadding: CGFloat = 24

    // Ghost in the Prompt cyber aesthetic (refined)
    static let primaryColor = Color(red: 0/255, green: 255/255, blue: 255/255) // Cyan #00FFFF
    static let dangerColor = Color(red: 255/255, green: 0/255, blue: 85/255) // Hot pink #FF0055
    static let warningColor = Color(red: 252/255, green: 211/255, blue: 77/255) // Yellow #FCD34D
    static let successColor = Color(red: 0/255, green: 255/255, blue: 127/255) // Neon green #00FF7F
    static let neutralColor = Color(red: 136/255, green: 136/255, blue: 136/255) // Gray
    static let backgroundColor = Color(red: 0/255, green: 0/255, blue: 0/255) // Black
    static let surfaceColor = Color(red: 17/255, green: 17/255, blue: 17/255) // Near black
    
    // Glassmorphic background
    static var glassBackground: some View {
        VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
    }
    
    // Category-specific colors and icons
    static func colorForCategory(_ category: String) -> Color {
        switch category {
        case "Apple Media Analysis":
            return primaryColor
        case "Incomplete Downloads":
            return warningColor
        case "Application Caches":
            return Color(red: 168/255, green: 85/255, blue: 247/255)
        case "Developer Files":
            return successColor
        case "System Logs":
            return neutralColor
        case "Docker":
            return primaryColor
        case "Trash Items":
            return dangerColor
        default:
            return neutralColor
        }
    }
    
    static func iconForCategory(_ category: String) -> String {
        switch category {
        case "Apple Media Analysis":
            return "photo.fill"
        case "Incomplete Downloads":
            return "arrow.down.circle"
        case "Application Caches":
            return "archivebox.fill"
        case "Developer Files":
            return "hammer.fill"
        case "System Logs":
            return "doc.text.fill"
        case "Docker":
            return "cube.box.fill"
        case "Trash Items":
            return "trash.fill"
        default:
            return "circle"
        }
    }
}

// VisualEffectView wrapper for NSVisualEffectView
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// Custom button style (Refined cyber aesthetic)
struct AccentButtonStyle: ButtonStyle {
    var isDestructive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .monospaced))
            .fontWeight(.semibold)
            .foregroundColor(AppTheme.backgroundColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .fill(isDestructive ? AppTheme.dangerColor : AppTheme.primaryColor)
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
                    .shadow(color: (isDestructive ? AppTheme.dangerColor : AppTheme.primaryColor).opacity(0.3), radius: configuration.isPressed ? 5 : 10)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

// Custom toggle style
struct CustomToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
                .font(.system(.body, design: .monospaced))

            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                RoundedRectangle(cornerRadius: 13)
                    .fill(configuration.isOn ? AppTheme.primaryColor.opacity(0.3) : AppTheme.surfaceColor)
                    .frame(width: 50, height: 26)
                    .overlay(
                        RoundedRectangle(cornerRadius: 13)
                            .stroke(configuration.isOn ? AppTheme.primaryColor : AppTheme.neutralColor, lineWidth: 1)
                    )

                Circle()
                    .fill(configuration.isOn ? AppTheme.primaryColor : AppTheme.neutralColor)
                    .frame(width: 20, height: 20)
                    .padding(3)
            }
            .onTapGesture {
                withAnimation(.spring(response: 0.3)) {
                    configuration.isOn.toggle()
                }
            }
        }
    }
}

// Pulsing animation modifier
struct PulsingAnimation: ViewModifier {
    @State private var isPulsing = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.03 : 1.0)
            .opacity(isPulsing ? 0.9 : 1.0)
            .animation(
                Animation
                    .easeInOut(duration: 1.5)
                    .repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear {
                isPulsing = true
            }
    }
}

// App icon view
struct AppIcon: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(AppTheme.backgroundColor)
                .frame(width: size, height: size)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.22)
                        .stroke(AppTheme.primaryColor, lineWidth: 2)
                )

            Image(systemName: "trash.slash")
                .font(.system(size: size / 2, weight: .bold, design: .monospaced))
                .foregroundColor(AppTheme.primaryColor)
        }
    }
}