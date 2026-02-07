import SwiftUI

// MARK: - Theme

enum Theme {
    // Minimalist dark color palette
    enum Colors {
        // Unified background - single tone for flatness
        static let background = Color(hex: "1a1a1a")
        static let backgroundSecondary = Color(hex: "1a1a1a")
        static let backgroundTertiary = Color(hex: "222222")
        
        // All panels use same background for seamlessness
        static let sidebar = background
        static let editor = background
        static let tabBar = background
        static let tabActive = background
        static let tabInactive = background
        static let statusBar = background
        static let inputBackground = Color(hex: "222222")
        
        // Text - neutral grays
        static let text = Color(hex: "d4d4d4")
        static let textSecondary = Color(hex: "888888")
        static let textMuted = Color(hex: "555555")
        static let textDisabled = Color(hex: "404040")
        
        // Minimal accent - subtle gray tones only
        static let accent = Color(hex: "888888")
        static let accentSecondary = Color(hex: "666666")
        static let accentGreen = Color(hex: "888888")
        static let accentOrange = Color(hex: "888888")
        static let accentRed = Color(hex: "888888")
        static let accentYellow = Color(hex: "888888")
        static let accentCyan = Color(hex: "888888")
        
        // Ultra-subtle UI elements
        static let border = Color(hex: "2a2a2a")
        static let divider = Color(hex: "282828")
        static let selection = Color.white.opacity(0.06)
        static let hover = Color.white.opacity(0.03)
        static let activeRow = Color.white.opacity(0.05)
        static let textSelection = Color(hex: "444444")
        
        // Grayscale folder/file icons
        static let folder = Color(hex: "666666")
        static let folderYellow = Color(hex: "666666")
        static let folderBlue = Color(hex: "666666")
        
        // Grayscale file type icons - all same gray
        static let fileMd = Color(hex: "666666")
        static let filePy = Color(hex: "666666")
        static let fileTs = Color(hex: "666666")
        static let fileDefault = Color(hex: "666666")
    }
    
    enum Fonts {
        // Base UI font - used throughout
        static let ui = Font.system(size: 13, weight: .regular)
        static let uiSmall = Font.system(size: 12, weight: .regular)
        static let uiMedium = Font.system(size: 13, weight: .medium)
        static let uiBold = Font.system(size: 13, weight: .semibold)
        
        // Specific UI elements
        static let title = Font.system(size: 13, weight: .medium)
        static let sidebarHeader = Font.system(size: 12, weight: .medium)
        static let tab = Font.system(size: 12, weight: .regular)
        static let breadcrumb = Font.system(size: 11, weight: .regular)
        static let statusBar = Font.system(size: 11, weight: .regular)
        
        // Icons and small elements
        static let icon = Font.system(size: 11, weight: .regular)
        static let iconSmall = Font.system(size: 9, weight: .medium)
        static let disclosure = Font.system(size: 8, weight: .medium)
        
        // Welcome screen
        static let welcomeIcon = Font.system(size: 36, weight: .thin)
        static let welcomeTitle = Font.system(size: 18, weight: .medium)
        
        // Editor
        static let editor = Font.system(size: 14, weight: .regular, design: .monospaced)
    }
    
    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let s: CGFloat = 6
        static let m: CGFloat = 8
        static let l: CGFloat = 12
        static let xl: CGFloat = 16
        static let xxl: CGFloat = 20
        static let xxxl: CGFloat = 24
    }
    
    enum Radius {
        static let small: CGFloat = 4
        static let medium: CGFloat = 6
        static let large: CGFloat = 8
    }
    
    enum Size {
        static let sidebarWidth: CGFloat = 220
        static let tabBarHeight: CGFloat = 36
        static let statusBarHeight: CGFloat = 24
        static let breadcrumbHeight: CGFloat = 28
        static let iconSmall: CGFloat = 14
        static let iconMedium: CGFloat = 16
        static let iconLarge: CGFloat = 18
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Fonts.uiMedium)
            .foregroundColor(Theme.Colors.text)
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.vertical, Theme.Spacing.m)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.small)
                    .fill(configuration.isPressed ? Theme.Colors.backgroundTertiary : Color(hex: "333333"))
            )
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Fonts.ui)
            .foregroundColor(Theme.Colors.textSecondary)
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.vertical, Theme.Spacing.m)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.small)
                    .fill(configuration.isPressed ? Theme.Colors.hover : Color.clear)
            )
    }
}

struct DestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Fonts.uiMedium)
            .foregroundColor(Theme.Colors.text)
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.vertical, Theme.Spacing.m)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.small)
                    .fill(configuration.isPressed ? Theme.Colors.backgroundTertiary : Color(hex: "333333"))
            )
    }
}

// MARK: - Deprecated Design enum for compatibility

enum Design {
    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 6
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
    }
    
    enum Radius {
        static let small: CGFloat = 4
        static let medium: CGFloat = 8
        static let large: CGFloat = 12
    }
    
    enum Fonts {
        static let largeTitle = Font.system(size: 28, weight: .bold, design: .rounded)
        static let title = Font.system(size: 20, weight: .semibold, design: .rounded)
        static let headline = Font.system(size: 14, weight: .semibold)
        static let subheadline = Font.system(size: 13, weight: .medium)
        static let body = Font.system(size: 13)
        static let caption = Font.system(size: 11)
        static let tiny = Font.system(size: 10)
        static let editorMono = Font.system(size: 14, weight: .regular, design: .monospaced)
        static let sidebarItem = Font.system(size: 13)
        static let sidebarHeader = Font.system(size: 11, weight: .semibold)
    }
    
    enum Colors {
        static let windowBackground = Theme.Colors.background
        static let sidebarBackground = Theme.Colors.sidebar
        static let editorBackground = Theme.Colors.editor
        static let cardBackground = Theme.Colors.backgroundSecondary
        static let primaryText = Theme.Colors.text
        static let secondaryText = Theme.Colors.textSecondary
        static let tertiaryText = Theme.Colors.textMuted
        static let placeholderText = Theme.Colors.textDisabled
        static let separator = Theme.Colors.divider
        static let selection = Theme.Colors.selection
        static let hoverBackground = Theme.Colors.hover
        static let success = Theme.Colors.accentGreen
        static let warning = Theme.Colors.accentOrange
        static let error = Theme.Colors.accentRed
        static let info = Theme.Colors.accent
        static let accent = Theme.Colors.accent
        static let accentSubtle = Theme.Colors.accent.opacity(0.1)
    }
    
    enum IconSize {
        static let small: CGFloat = 12
        static let medium: CGFloat = 14
        static let large: CGFloat = 16
        static let xlarge: CGFloat = 20
        static let hero: CGFloat = 48
    }
    
    enum Shadows {
        static let subtle = Color.black.opacity(0.2)
        static let medium = Color.black.opacity(0.3)
    }
}
