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
            background = Color(hex: 0xE9F8FE)
            surface = Color.white.opacity(0.84)
            elevatedSurface = Color(hex: 0xF5FCFF)
            primaryText = Color(hex: 0x293D50)
            secondaryText = Color(hex: 0x576E82)
            accent = Color(hex: 0x2875A3)
            accentSoft = Color(hex: 0xDCEFFC)
            rest = Color(hex: 0xDEF3EF)
            reading = Color(hex: 0xFFF1D5)
            important = Color(hex: 0xFBE5EF)
            pending = Color(hex: 0xEAE7FA)
            adjustment = Color(hex: 0xDDEFFA)
            warning = Color(hex: 0x9C6030)
            critical = Color(hex: 0xAF426B)
            success = Color(hex: 0x367765)
            shadow = Color(hex: 0x79B8D5).opacity(0.13)
        case (.pixelCat, true):
            background = Color(hex: 0x152B3A)
            surface = Color(hex: 0x233F51).opacity(0.96)
            elevatedSurface = Color(hex: 0x2C4B5E)
            primaryText = Color(hex: 0xECF7FE)
            secondaryText = Color(hex: 0xB1CBDC)
            accent = Color(hex: 0x9BD7F6)
            accentSoft = Color(hex: 0x30566E)
            rest = Color(hex: 0x2D514F)
            reading = Color(hex: 0x514936)
            important = Color(hex: 0x573D51)
            pending = Color(hex: 0x414364)
            adjustment = Color(hex: 0x304E69)
            warning = Color(hex: 0xEFBE87)
            critical = Color(hex: 0xF2A6C0)
            success = Color(hex: 0x9AD7C4)
            shadow = Color(hex: 0x061722).opacity(0.26)
        }
    }

    var cardRadius: CGFloat { isCatSkin ? 26 : MiraRadius.medium }
    var cardBorder: Color {
        isCatSkin ? Color.white.opacity(isDark ? 0.14 : 0.88) : primaryText.opacity(0.06)
    }
    var botanical: Color { Color(hex: isDark ? 0x72B8B5 : 0x94CFCC) }
    var onAccent: Color { isCatSkin && isDark ? background : .white }
    var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: isCatSkin
                ? [background, Color(hex: isDark ? 0x1A394B : 0xDDF4FD), background]
                : [background, background],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    var actionGradient: LinearGradient {
        LinearGradient(
            colors: isCatSkin
                ? [Color(hex: isDark ? 0xB9E5FA : 0x3079A6), Color(hex: isDark ? 0x82C4EA : 0x246E9B)]
                : [accent, accent],
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

    /// Soft background for an event chip; text stays primaryText on top of it.
    func fill(for tag: EventColorTag) -> Color {
        switch (tag, isDark) {
        case (.sakura, false): Color(hex: 0xF9D5DF)
        case (.peach, false): Color(hex: 0xFCDCC7)
        case (.lemon, false): Color(hex: 0xF7EAB2)
        case (.mint, false): Color(hex: 0xCDEBDD)
        case (.sky, false): Color(hex: 0xD0E4F7)
        case (.lavender, false): Color(hex: 0xE3D9F4)
        case (.cocoa, false): Color(hex: 0xE8D9CB)
        case (.gray, false): Color(hex: 0xE4E5E8)
        case (.sakura, true): Color(hex: 0x6A3A49)
        case (.peach, true): Color(hex: 0x6B4633)
        case (.lemon, true): Color(hex: 0x5C5230)
        case (.mint, true): Color(hex: 0x2F5446)
        case (.sky, true): Color(hex: 0x2F4A66)
        case (.lavender, true): Color(hex: 0x4A3D66)
        case (.cocoa, true): Color(hex: 0x52433A)
        case (.gray, true): Color(hex: 0x45474C)
        }
    }

    /// Saturated version used for the picker dot and the chip's leading bar.
    func swatch(for tag: EventColorTag) -> Color {
        switch tag {
        case .sakura: Color(hex: 0xE8879F)
        case .peach: Color(hex: 0xF0A072)
        case .lemon: Color(hex: 0xE2C044)
        case .mint: Color(hex: 0x62BE98)
        case .sky: Color(hex: 0x68A4DA)
        case .lavender: Color(hex: 0xA28CD6)
        case .cocoa: Color(hex: 0xAE8868)
        case .gray: Color(hex: 0x9C9FA6)
        }
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
                    .strokeBorder(palette.cardBorder, lineWidth: palette.isCatSkin ? 1.3 : 1)
            }
            .shadow(color: palette.shadow, radius: palette.isCatSkin ? 18 : 16, y: 7)
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
