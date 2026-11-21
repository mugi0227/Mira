import SwiftUI

/// A quiet, static stamp: no alert color, looping motion, or extra action.
/// Its own layout space keeps it clear of the reply and the input bar.
struct CatErrorStamp: View {
    let theme: AppThemeKind
    let palette: MiraThemePalette
    @ScaledMetric(relativeTo: .caption) private var catWidth: CGFloat = 76

    private var ink: Color { palette.secondaryText }
    private var isOutline: Bool { theme == .onelineCat }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                if isOutline {
                    ErrorCatOutline()
                        .stroke(ink, style: StrokeStyle(lineWidth: 2.8, lineCap: .round, lineJoin: .round))
                } else {
                    ErrorCatOutline().fill(ink)
                }
                ErrorCatFace()
                    .stroke(isOutline ? ink : palette.surface,
                            style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
            .frame(width: catWidth, height: catWidth * 0.7)
            .rotationEffect(.degrees(-7))
            .padding(6)

            Text("だめだ〜")
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("だめだ〜、目がばつ印の猫")
        .accessibilityIdentifier("catErrorStamp")
    }
}

private struct ErrorCatOutline: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
            }
            p.move(to: point(0.1, 0.69))
            p.addQuadCurve(to: point(0.16, 0.39), control: point(0.06, 0.51))
            p.addLine(to: point(0.14, 0.09))
            p.addQuadCurve(to: point(0.37, 0.25), control: point(0.3, 0.12))
            p.addQuadCurve(to: point(0.62, 0.25), control: point(0.5, 0.19))
            p.addQuadCurve(to: point(0.85, 0.09), control: point(0.72, 0.12))
            p.addLine(to: point(0.83, 0.4))
            p.addCurve(to: point(0.84, 0.83), control1: point(0.96, 0.58), control2: point(0.99, 0.75))
            p.addQuadCurve(to: point(0.18, 0.85), control: point(0.52, 0.98))
            p.addQuadCurve(to: point(0.1, 0.69), control: point(0.08, 0.83))
            p.closeSubpath()
        }
    }
}

private struct ErrorCatFace: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
            }
            for x: CGFloat in [0.34, 0.65] {
                p.move(to: point(x - 0.045, 0.43))
                p.addLine(to: point(x + 0.045, 0.55))
                p.move(to: point(x + 0.045, 0.43))
                p.addLine(to: point(x - 0.045, 0.55))
            }
            p.move(to: point(0.44, 0.7))
            p.addQuadCurve(to: point(0.56, 0.7), control: point(0.5, 0.6))
        }
    }
}
