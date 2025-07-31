import SwiftUI

struct AppTheme {
    // Standard spacing and dimensions
    static let cornerRadius: CGFloat = 8
    static let largeCornerRadius: CGFloat = 12
    static let standardPadding: CGFloat = 12
    static let smallPadding: CGFloat = 6
    static let largePadding: CGFloat = 24
    
    // Color palette
    static let primaryColor = Color.blue
    static let dangerColor = Color.red
    static let warningColor = Color.orange
    static let successColor = Color.green
    static let neutralColor = Color.gray
    
    // Category-specific colors and icons
    static func colorForCategory(_ category: String) -> Color {
        switch category {
        case "Apple Media Analysis":
            return Color.blue
        case "Incomplete Downloads":
            return Color.orange
        case "Application Caches":
            return Color.purple
        case "Developer Files":
            return Color.teal
        case "System Logs":
            return Color.gray
        case "Docker":
            return Color.cyan
        case "Trash Items":
            return Color.red
        default:
            return Color.secondary
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

// Custom button style with accent color
struct AccentButtonStyle: ButtonStyle {
    var isDestructive: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .fill(isDestructive ? AppTheme.dangerColor : AppTheme.primaryColor)
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

// Custom toggle style
struct CustomToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                RoundedRectangle(cornerRadius: 15)
                    .fill(configuration.isOn ? AppTheme.primaryColor : Color.gray.opacity(0.3))
                    .frame(width: 50, height: 30)
                
                RoundedRectangle(cornerRadius: 13)
                    .fill(Color.white)
                    .padding(4)
                    .frame(width: 30, height: 30)
                    .offset(x: configuration.isOn ? 10 : -10)
            }
            .onTapGesture {
                withAnimation(.spring()) {
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
            RoundedRectangle(cornerRadius: size / 5)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.blue, Color.purple]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
            
            Image(systemName: "externaldrive.badge.xmark")
                .font(.system(size: size / 2))
                .foregroundColor(.white)
        }
    }
}