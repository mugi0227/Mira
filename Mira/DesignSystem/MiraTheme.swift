import SwiftUI

struct MiraThemePalette {
    let isCatSkin: Bool
    let isDark: Bool
    let background: Color
    let surface: Color
    let elevatedSurface: Color
    let primaryText: Color
    let secondaryText: Color
    let accent: Color
    let accentSoft: Color
    let rest: Color
    let reading: Color
    let important: Color
    let pending: Color
    let adjustment: Color
    let warning: Color
    let critical: Color
    let success: Color
    let shadow: Color

    init(kind: AppThemeKind, colorScheme: ColorScheme, colorStyle: AppColorStyle = .blue) {
        let isDark = colorScheme == .dark
        self.isDark = isDark
        isCatSkin = kind.isCat
        let colors: (background: UInt32, surface: UInt32, accent: UInt32, soft: UInt32)
        switch (colorStyle, isDark) {
        case (.blue, false):
            colors = (0xF2F7FC, 0xFFFFFF, 0x406B94, 0xE0EDF8)
        case (.blue, true):
            colors = (0x18232E, 0x243342, 0xAED4F3, 0x344B60)
        case (.sage, false):
            colors = (0xF7F3EB, 0xFFFCF7, 0x5D6C53, 0xE4E8DA)
        case (.sage, true):
            colors = (0x20231F, 0x2B3029, 0xC3D0AF, 0x414C38)
        case (.rose, false):
            colors = (0xFBF3F5, 0xFFFBFC, 0x96586C, 0xF3DFE6)
        case (.rose, true):
            colors = (0x2B2026, 0x3A2B33, 0xE5B6C6, 0x543C47)
        case (.lavender, false):
            colors = (0xF6F3FB, 0xFDFBFF, 0x76619A, 0xE9E1F3)
        case (.lavender, true):
            colors = (0x24212D, 0x322D3E, 0xCCBDE4, 0x4A415C)
        }
        background = Color(hex: colors.background)
        surface = Color(hex: colors.surface)
        elevatedSurface = surface
        primaryText = Color(hex: isDark ? 0xF3F5F7 : 0x293746)
        secondaryText = Color(hex: isDark ? 0xBDC8D1 : 0x5C6B78)
        accent = Color(hex: colors.accent)
        accentSoft = Color(hex: colors.soft)
        rest = Color(hex: isDark ? 0x35483D : 0xDCE9E2)
        reading = Color(hex: isDark ? 0x4A4135 : 0xEEE4D5)
        important = Color(hex: isDark ? 0x503A40 : 0xF0DDE1)
        pending = Color(hex: isDark ? 0x433A50 : 0xE7E0F0)
        adjustment = Color(hex: isDark ? 0x344657 : 0xDCE7F1)
        warning = Color(hex: isDark ? 0xE3A26E : 0x956039)
        critical = Color(hex: isDark ? 0xED8F8F : 0xA84545)
        success = Color(hex: isDark ? 0x9BC5A6 : 0x4F765C)
        shadow = Color.black.opacity(isDark ? 0.28 : 0.08)
    }

    var cardRadius: CGFloat { MiraRadius.large }
    var cardBorder: Color {
        primaryText.opacity(isDark ? 0.12 : 0.08)
    }
    var botanical: Color { accent.opacity(0.65) }
    var onAccent: Color { isDark ? background : .white }
    var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [background, background],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    var actionGradient: LinearGradient {
        LinearGradient(
            colors: [accent, accent],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    func goalTint(for symbol: String) -> Color {
        if symbol.contains("moon") { return pending }
        if symbol.contains("heart") { return important }
        return adjustment
    }

    func color(for item: CalendarItemSnapshot) -> Color {
        if item.kind == .birthday { return important }
        if item.kind == .margin {
            switch item.marginKind {
            case .rest, .freeEvening, .solo: return rest
            case .reading: return reading
            case .personalProject, .custom: return accentSoft
            case .importantPeople: return important
            case .none: return rest
            }
        }
        if let tag = item.colorTag { return fill(for: tag) }
        if item.isImportantTime { return important }
        return surface
    }

    /// Chip background in the calendar: light tones as they are, medium
    /// tones softened, deep tones and black solid with white text.
    func fill(for tag: EventColorTag) -> Color {
        let base = Color(hex: tag.swatchHex)
        switch tag.tone {
        case .light: return isDark ? base.opacity(0.38) : base
        case .medium: return base.opacity(isDark ? 0.6 : 0.5)
        case .deep: return base
        case .neutral:
            switch tag {
            case .white: return isDark ? Color(hex: 0xEDEDED) : .white
            case .gray: return Color(hex: isDark ? 0x5A5A5A : 0xE0E0E0)
            default: return base
            }
        }
    }

    /// Text that stays readable on the chip.
    func chipText(for tag: EventColorTag) -> Color {
        if tag.prefersLightText { return .white }
        if tag == .white { return Color(hex: 0x333333) }
        return primaryText
    }

    func swatch(for tag: EventColorTag) -> Color {
        Color(hex: tag.swatchHex)
    }

    func bar(for tag: EventColorTag) -> Color {
        Color(hex: tag.barHex)
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

enum MiraSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

enum MiraRadius {
    static let small: CGFloat = 16
    static let medium: CGFloat = 24
    static let large: CGFloat = 34
}

enum MiraMotion {
    static let quick = Animation.spring(response: 0.28, dampingFraction: 0.72)
    static let standard = Animation.spring(response: 0.42, dampingFraction: 0.74)
    static let gentle = Animation.spring(response: 0.55, dampingFraction: 0.86)

    static func selection(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : standard
    }
}

struct MiraCardModifier: ViewModifier {
    let palette: MiraThemePalette
    var padding: CGFloat = MiraSpacing.md
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: palette.cardRadius, style: .continuous)
                    .fill(reduceTransparency ? palette.elevatedSurface : palette.surface)
            }
            .overlay {
                RoundedRectangle(cornerRadius: palette.cardRadius, style: .continuous)
                    .strokeBorder(palette.cardBorder, lineWidth: 2)
            }
            .shadow(color: palette.shadow, radius: 12, y: 4)
    }
}

extension View {
    func miraCard(_ palette: MiraThemePalette, padding: CGFloat = MiraSpacing.md) -> some View {
        modifier(MiraCardModifier(palette: palette, padding: padding))
    }
}

struct MiraPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.86 : 1)
            .scaleEffect(
                x: reduceMotion ? 1 : (configuration.isPressed ? 0.95 : 1),
                y: reduceMotion ? 1 : (configuration.isPressed ? 0.92 : 1)
            )
            .animation(reduceMotion ? nil : MiraMotion.quick, value: configuration.isPressed)
            .contentShape(Rectangle())
    }
}
