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

    init(kind: AppThemeKind, colorScheme: ColorScheme) {
        let isDark = colorScheme == .dark
        self.isDark = isDark
        isCatSkin = kind == .pixelCat
        switch (kind, isDark) {
        case (.softMinimal, false):
            background = Color(hex: 0xF7F6F2)
            surface = .white
            elevatedSurface = Color(hex: 0xFCFCFA)
            primaryText = Color(hex: 0x262823)
            secondaryText = Color(hex: 0x686B63)
            accent = Color(hex: 0x5E7867)
            accentSoft = Color(hex: 0xE2ECE4)
            rest = Color(hex: 0xDCE9E2)
            reading = Color(hex: 0xEEE4D5)
            important = Color(hex: 0xF0DDE1)
            pending = Color(hex: 0xE7E0F0)
            adjustment = Color(hex: 0xDCE7F1)
            warning = Color(hex: 0xB36A38)
            critical = Color(hex: 0xA84545)
            success = Color(hex: 0x4F765C)
            shadow = Color.black.opacity(0.08)
        case (.softMinimal, true):
            background = Color(hex: 0x171A17)
            surface = Color(hex: 0x222622)
            elevatedSurface = Color(hex: 0x292E29)
            primaryText = Color(hex: 0xF2F2ED)
            secondaryText = Color(hex: 0xBFC3BA)
            accent = Color(hex: 0xA8C4AF)
            accentSoft = Color(hex: 0x34443A)
            rest = Color(hex: 0x35483D)
            reading = Color(hex: 0x4A4135)
            important = Color(hex: 0x503A40)
            pending = Color(hex: 0x433A50)
            adjustment = Color(hex: 0x344657)
            warning = Color(hex: 0xE3A26E)
            critical = Color(hex: 0xED8F8F)
            success = Color(hex: 0x9BC5A6)
            shadow = Color.black.opacity(0.28)
        case (.pixelCat, false):
            background = Color(hex: 0xF7F3EB)
            surface = Color(hex: 0xFFFCF7)
            elevatedSurface = Color(hex: 0xFFFCF7)
            primaryText = Color(hex: 0x353831)
            secondaryText = Color(hex: 0x6D7065)
            accent = Color(hex: 0x5D6C53)
            accentSoft = Color(hex: 0xE4E8DA)
            rest = Color(hex: 0xDEE5D6)
            reading = Color(hex: 0xEEE0CB)
            important = Color(hex: 0xEEDDD7)
            pending = Color(hex: 0xE4DEEC)
            adjustment = Color(hex: 0xDEE5E6)
            warning = Color(hex: 0x956039)
            critical = Color(hex: 0xA54D52)
            success = Color(hex: 0x526B4A)
            shadow = Color(hex: 0x55503E).opacity(0.08)
        case (.pixelCat, true):
            background = Color(hex: 0x20231F)
            surface = Color(hex: 0x2B3029)
            elevatedSurface = Color(hex: 0x343A31)
            primaryText = Color(hex: 0xF4F1E8)
            secondaryText = Color(hex: 0xC0C5B7)
            accent = Color(hex: 0xC3D0AF)
            accentSoft = Color(hex: 0x414C38)
            rest = Color(hex: 0x3D4C36)
            reading = Color(hex: 0x504737)
            important = Color(hex: 0x523E3C)
            pending = Color(hex: 0x484052)
            adjustment = Color(hex: 0x3A484C)
            warning = Color(hex: 0xEFBE87)
            critical = Color(hex: 0xF2A6C0)
            success = Color(hex: 0x9AD7C4)
            shadow = Color(hex: 0x061722).opacity(0.26)
        }
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
    static let large: CGFloat = 30
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
                    .strokeBorder(palette.cardBorder, lineWidth: 1.5)
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
