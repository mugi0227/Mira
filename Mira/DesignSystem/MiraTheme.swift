import SwiftUI

struct MiraThemePalette {
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
            background = Color(hex: 0xFFF8F2)
            surface = Color(hex: 0xFFFEFC)
            elevatedSurface = Color(hex: 0xFFF4E9)
            primaryText = Color(hex: 0x352D31)
            secondaryText = Color(hex: 0x74666C)
            accent = Color(hex: 0xC26F87)
            accentSoft = Color(hex: 0xF8DFE7)
            rest = Color(hex: 0xDCEDE8)
            reading = Color(hex: 0xF6E6BE)
            important = Color(hex: 0xF6D7DF)
            pending = Color(hex: 0xE9DDF4)
            adjustment = Color(hex: 0xDCEAF7)
            warning = Color(hex: 0xC5763B)
            critical = Color(hex: 0xB84C5E)
            success = Color(hex: 0x4F8871)
            shadow = Color(hex: 0x6D4C59).opacity(0.10)
        case (.pixelCat, true):
            background = Color(hex: 0x211B20)
            surface = Color(hex: 0x2D252B)
            elevatedSurface = Color(hex: 0x372D34)
            primaryText = Color(hex: 0xFFF3F6)
            secondaryText = Color(hex: 0xD4C0C8)
            accent = Color(hex: 0xF2A6BB)
            accentSoft = Color(hex: 0x573844)
            rest = Color(hex: 0x35514C)
            reading = Color(hex: 0x55492D)
            important = Color(hex: 0x5A3541)
            pending = Color(hex: 0x4E3A5E)
            adjustment = Color(hex: 0x344B61)
            warning = Color(hex: 0xE8A36D)
            critical = Color(hex: 0xF08799)
            success = Color(hex: 0x90C8B2)
            shadow = Color.black.opacity(0.32)
        }
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
        if item.isImportantTime { return important }
        return surface
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
    static let small: CGFloat = 12
    static let medium: CGFloat = 18
    static let large: CGFloat = 26
}

enum MiraMotion {
    static let quick = Animation.easeOut(duration: 0.16)
    static let standard = Animation.spring(response: 0.38, dampingFraction: 0.82)
    static let gentle = Animation.spring(response: 0.55, dampingFraction: 0.9)
}

struct MiraCardModifier: ViewModifier {
    let palette: MiraThemePalette
    var padding: CGFloat = MiraSpacing.md

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: MiraRadius.medium, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MiraRadius.medium, style: .continuous)
                    .stroke(palette.primaryText.opacity(0.06), lineWidth: 1)
            }
            .shadow(color: palette.shadow, radius: 16, y: 7)
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
            .opacity(configuration.isPressed ? 0.78 : 1)
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.98 : 1))
            .animation(reduceMotion ? nil : MiraMotion.quick, value: configuration.isPressed)
            .contentShape(Rectangle())
    }
}
