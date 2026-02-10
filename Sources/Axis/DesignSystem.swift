import SwiftUI
import AppKit

// MARK: - Theme

enum Theme {
    // Adaptive color palette - resolves based on current appearance
    enum Colors {
        private static func adaptive(dark: String, light: String) -> Color {
            Color(NSColor(name: nil) { appearance in
                let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                return isDark ? NSColor(Color(hex: dark)) : NSColor(Color(hex: light))
            })
        }

        // Unified background
        static var background: Color { adaptive(dark: "1a1a1a", light: "ffffff") }
        static var backgroundSecondary: Color { adaptive(dark: "1a1a1a", light: "ffffff") }
        static var backgroundTertiary: Color { adaptive(dark: "222222", light: "f0f0f0") }

        // All panels use same background for seamlessness
        static var sidebar: Color { background }
        static var editor: Color { background }
        static var tabBar: Color { background }
        static var tabActive: Color { background }
        static var tabInactive: Color { background }
        static var statusBar: Color { background }
        static var inputBackground: Color { adaptive(dark: "222222", light: "f0f0f0") }

        // Text
        static var text: Color { adaptive(dark: "d4d4d4", light: "1a1a1a") }
        static var textSecondary: Color { adaptive(dark: "888888", light: "666666") }
        static var textMuted: Color { adaptive(dark: "555555", light: "999999") }
        static var textDisabled: Color { adaptive(dark: "404040", light: "bbbbbb") }

        // Minimal accent
        static var accent: Color { adaptive(dark: "888888", light: "666666") }
        static var accentSecondary: Color { adaptive(dark: "666666", light: "888888") }
        static var accentGreen: Color { adaptive(dark: "888888", light: "666666") }
        static var accentOrange: Color { adaptive(dark: "888888", light: "666666") }
        static var accentRed: Color { adaptive(dark: "888888", light: "666666") }
        static var accentYellow: Color { adaptive(dark: "888888", light: "666666") }
        static var accentCyan: Color { adaptive(dark: "888888", light: "666666") }

        // UI elements
        static var border: Color { adaptive(dark: "2a2a2a", light: "e0e0e0") }
        static var divider: Color { adaptive(dark: "282828", light: "e5e5e5") }
        static var selection: Color {
            Color(NSColor(name: nil) { appearance in
                let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                return isDark ? NSColor.white.withAlphaComponent(0.08) : NSColor.black.withAlphaComponent(0.07)
            })
        }
        static var hover: Color {
            Color(NSColor(name: nil) { appearance in
                let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                return isDark ? NSColor.white.withAlphaComponent(0.04) : NSColor.black.withAlphaComponent(0.04)
            })
        }
        static var activeRow: Color {
            Color(NSColor(name: nil) { appearance in
                let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                return isDark ? NSColor.white.withAlphaComponent(0.06) : NSColor.black.withAlphaComponent(0.06)
            })
        }
        // Subtle current-line highlight for the editor
        static var currentLine: Color {
            Color(NSColor(name: nil) { appearance in
                let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                return isDark ? NSColor.white.withAlphaComponent(0.03) : NSColor.black.withAlphaComponent(0.025)
            })
        }
        // Thin active-tab indicator
        static var tabIndicator: Color { adaptive(dark: "555555", light: "888888") }
        static var textSelection: Color { adaptive(dark: "444444", light: "b4d7ff") }

        // Folder/file icons
        static var folder: Color { adaptive(dark: "666666", light: "888888") }
        static var folderYellow: Color { adaptive(dark: "666666", light: "888888") }
        static var folderBlue: Color { adaptive(dark: "666666", light: "888888") }

        static var fileMd: Color { adaptive(dark: "666666", light: "888888") }
        static var filePy: Color { adaptive(dark: "666666", light: "888888") }
        static var fileTs: Color { adaptive(dark: "666666", light: "888888") }
        static var fileDefault: Color { adaptive(dark: "666666", light: "888888") }

        // Button backgrounds
        static var buttonBackground: Color { adaptive(dark: "333333", light: "e8e8e8") }

        // Markdown styling colors (for NSTextView)
        static var mdHeading: Color { adaptive(dark: "e8e8e8", light: "1a1a1a") }
        static var mdCodeBg: Color { adaptive(dark: "1a1a1a", light: "ffffff") }
        static var mdCodeText: Color { adaptive(dark: "b0b0b0", light: "555555") }
        static var mdFenceMuted: Color { adaptive(dark: "4a4a4a", light: "bbbbbb") }
        static var mdLangTag: Color { adaptive(dark: "6a6a6a", light: "999999") }
        static var mdInlineCode: Color { adaptive(dark: "a0a0a0", light: "555555") }
        static var mdInlineCodeBg: Color { adaptive(dark: "222222", light: "f0f0f0") }
        static var mdLink: Color { adaptive(dark: "6a9fb5", light: "3a7ca5") }
        static var mdHrLine: Color { adaptive(dark: "333333", light: "cccccc") }
        static var mdHrStrike: Color { adaptive(dark: "555555", light: "aaaaaa") }

        // Syntax highlighting colors (code blocks)
        static var syntaxKeyword: Color { adaptive(dark: "c678dd", light: "a626a4") }
        static var syntaxType: Color { adaptive(dark: "61afef", light: "4078f2") }
        static var syntaxString: Color { adaptive(dark: "98c379", light: "50a14f") }
        static var syntaxComment: Color { adaptive(dark: "5c6370", light: "a0a1a7") }
        static var syntaxNumber: Color { adaptive(dark: "d19a66", light: "986801") }
        static var syntaxFunc: Color { adaptive(dark: "e5c07b", light: "c18401") }
        static var syntaxTag: Color { adaptive(dark: "e06c75", light: "e45649") }
        static var syntaxAttr: Color { adaptive(dark: "d19a66", light: "986801") }
        static var syntaxProperty: Color { adaptive(dark: "61afef", light: "4078f2") }
        static var syntaxSelector: Color { adaptive(dark: "e06c75", light: "e45649") }
        static var syntaxJsonKey: Color { adaptive(dark: "e06c75", light: "e45649") }
    }
    
    enum Fonts {
        // Roboto Mono font family used throughout the app
        private static func roboto(size: CGFloat, weight: FontWeight = .regular) -> Font {
            switch weight {
            case .light:
                return Font.custom("RobotoMono-Light", size: size)
            case .regular:
                return Font.custom("RobotoMono-Regular", size: size)
            case .medium:
                return Font.custom("RobotoMono-Medium", size: size)
            case .semibold, .bold:
                return Font.custom("RobotoMono-Bold", size: size)
            }
        }

        enum FontWeight {
            case light, regular, medium, semibold, bold
        }

        // Base UI font - used throughout
        static let ui = roboto(size: 13)
        static let uiSmall = roboto(size: 12)
        static let uiMedium = roboto(size: 13, weight: .medium)
        static let uiBold = roboto(size: 13, weight: .bold)

        // Specific UI elements
        static let title = roboto(size: 13, weight: .medium)
        static let sidebarHeader = roboto(size: 12, weight: .medium)
        static let tab = roboto(size: 12)
        static let breadcrumb = roboto(size: 11)
        static let statusBar = roboto(size: 11)

        // Icons and small elements
        static let icon = Font.system(size: 11, weight: .regular)
        static let iconSmall = Font.system(size: 9, weight: .medium)
        static let disclosure = Font.system(size: 8, weight: .medium)

        // Welcome screen
        static let welcomeIcon = Font.system(size: 36, weight: .thin)
        static let welcomeTitle = roboto(size: 18, weight: .medium)

        // Editor
        static let editor = roboto(size: 14)
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
        static let terminalPanelHeight: CGFloat = 220
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
                    .fill(configuration.isPressed ? Theme.Colors.backgroundTertiary : Theme.Colors.buttonBackground)
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
                    .fill(configuration.isPressed ? Theme.Colors.backgroundTertiary : Theme.Colors.buttonBackground)
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
        static let largeTitle = Font.custom("RobotoMono-Bold", size: 28)
        static let title = Font.custom("RobotoMono-Bold", size: 20)
        static let headline = Font.custom("RobotoMono-Bold", size: 14)
        static let subheadline = Font.custom("RobotoMono-Medium", size: 13)
        static let body = Font.custom("RobotoMono-Regular", size: 13)
        static let caption = Font.custom("RobotoMono-Regular", size: 11)
        static let tiny = Font.custom("RobotoMono-Regular", size: 10)
        static let editorMono = Font.custom("RobotoMono-Regular", size: 14)
        static let sidebarItem = Font.custom("RobotoMono-Regular", size: 13)
        static let sidebarHeader = Font.custom("RobotoMono-Bold", size: 11)
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
