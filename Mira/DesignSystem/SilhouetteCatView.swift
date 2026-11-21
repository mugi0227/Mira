import SwiftUI

struct MiraCatView: View {
    @Environment(MiraStore.self) private var store
    let mood: CatMood
    var size: CGFloat = 72

    var body: some View {
        MiraCatArtwork(theme: store.theme, mood: mood, size: size)
    }
}

struct MiraCatArtwork: View {
    let theme: AppThemeKind
    let mood: CatMood
    var size: CGFloat = 72

    var body: some View {
        if theme == .silhouetteCat {
            SilhouetteCatView(mood: mood, size: size)
        } else {
            PixelCatView(mood: mood, size: size)
        }
    }
}

struct SilhouetteCatView: View {
    enum Pose: Equatable { case sitting, loaf, peeking }

    let mood: CatMood
    var size: CGFloat = 72
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static func pose(for mood: CatMood) -> Pose {
        switch mood {
        case .idle, .thinking, .inviting, .happy, .celebrating: .sitting
        case .relaxed, .sleeping: .loaf
        case .tired, .warning: .peeking
        }
    }

    var body: some View {
        Group {
            if reduceMotion {
                artwork
            } else {
                artwork.phaseAnimator([false, true]) { content, floating in
                    content.offset(y: floating ? -2 : 2)
                } animation: { _ in .easeInOut(duration: 1.8) }
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityIdentifier("silhouetteCat")
    }

    private var color: Color {
        switch Self.pose(for: mood) {
        case .sitting: Color(hex: colorScheme == .dark ? 0x8F9C80 : 0xA9B49A)
        case .loaf: Color(hex: colorScheme == .dark ? 0xBAA386 : 0xDDC8A9)
        case .peeking: Color(hex: colorScheme == .dark ? 0xAD9EAF : 0xCFC2CF)
        }
    }

    private var artwork: some View {
        Canvas { context, _ in
            let pose = Self.pose(for: mood)
            let transform = CGAffineTransform(scaleX: size / 100, y: size / 100)
            func fill(_ path: Path, _ tint: Color) {
                context.fill(path.applying(transform), with: .color(tint))
            }
            let body = Path { p in
                switch pose {
                case .sitting:
                    p.move(to: CGPoint(x: 24, y: 46))
                    p.addCurve(to: CGPoint(x: 27, y: 19), control1: CGPoint(x: 20, y: 36), control2: CGPoint(x: 23, y: 26))
                    p.addCurve(to: CGPoint(x: 32, y: 9), control1: CGPoint(x: 28, y: 11), control2: CGPoint(x: 29, y: 6))
                    p.addLine(to: CGPoint(x: 41, y: 15))
                    p.addQuadCurve(to: CGPoint(x: 59, y: 15), control: CGPoint(x: 50, y: 13))
                    p.addLine(to: CGPoint(x: 68, y: 9))
                    p.addQuadCurve(to: CGPoint(x: 74, y: 22), control: CGPoint(x: 72, y: 6))
                    p.addQuadCurve(to: CGPoint(x: 76, y: 46), control: CGPoint(x: 81, y: 35))
                    p.addCurve(to: CGPoint(x: 65, y: 91), control1: CGPoint(x: 99, y: 78), control2: CGPoint(x: 92, y: 94))
                    p.addQuadCurve(to: CGPoint(x: 35, y: 91), control: CGPoint(x: 50, y: 94))
                    p.addCurve(to: CGPoint(x: 24, y: 46), control1: CGPoint(x: 8, y: 96), control2: CGPoint(x: 1, y: 78))
                case .loaf, .peeking:
                    let y: CGFloat = pose == .loaf ? 36 : 48
                    p.move(to: CGPoint(x: 10, y: 68))
                    p.addQuadCurve(to: CGPoint(x: 17, y: y + 6), control: CGPoint(x: 10, y: y + 17))
                    p.addQuadCurve(to: CGPoint(x: 23, y: y - 6), control: CGPoint(x: 20, y: y - 9))
                    p.addLine(to: CGPoint(x: 33, y: y))
                    p.addQuadCurve(to: CGPoint(x: 51, y: y), control: CGPoint(x: 42, y: y - 2))
                    p.addLine(to: CGPoint(x: 61, y: y - 6))
                    p.addQuadCurve(to: CGPoint(x: 68, y: y + 1), control: CGPoint(x: 65, y: y - 9))
                    p.addCurve(to: CGPoint(x: 92, y: 73), control1: CGPoint(x: 86, y: y), control2: CGPoint(x: 95, y: 55))
                    p.addQuadCurve(to: CGPoint(x: 74, y: 89), control: CGPoint(x: 92, y: 89))
                    p.addLine(to: CGPoint(x: 28, y: 89))
                    p.addQuadCurve(to: CGPoint(x: 10, y: 68), control: CGPoint(x: 8, y: 89))
                }
                p.closeSubpath()
            }
            fill(body, color)
            if pose == .peeking {
                for x in [CGFloat(8), 74] {
                    fill(Path(ellipseIn: CGRect(x: x, y: 79, width: 19, height: 12)), color)
                }
            }
            let eyeY: CGFloat = pose == .sitting ? 31 : (pose == .loaf ? 53 : 73)
            let eyes: [CGFloat] = pose == .loaf ? [31, 50] : [41, 59]
            for x in eyes {
                if mood == .sleeping {
                    var eye = Path()
                    eye.move(to: CGPoint(x: x - 2, y: eyeY))
                    eye.addQuadCurve(to: CGPoint(x: x + 2, y: eyeY), control: CGPoint(x: x, y: eyeY + 2))
                    context.stroke(eye.applying(transform), with: .color(Color(hex: 0xF7F1E8)), style: StrokeStyle(lineWidth: size * 0.016, lineCap: .round))
                } else {
                    fill(Path(ellipseIn: CGRect(x: x - 2.4, y: eyeY - 2.4, width: 4.8, height: 4.8)), Color(hex: 0xF7F1E8))
                }
            }
        }
    }

    private var label: String {
        switch mood {
        case .relaxed, .sleeping: "くつろいでいる猫"
        case .tired: "少し疲れている猫"
        case .warning: "注意を知らせる猫"
        case .happy, .celebrating: "喜んでいる猫"
        case .thinking: "考えている猫"
        case .idle: "座っている猫"
        case .inviting: "こちらへ招いている猫"
        }
    }
}
