import SwiftUI

/// An opt-in detail, not a decoration on every card. The reserved space belongs
/// to the card so the ears never cover the preceding content while scrolling.
struct MiraPeekingCatCardModifier: ViewModifier {
    let palette: MiraThemePalette
    let theme: AppThemeKind
    var padding: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false

    private var showsCat: Bool { theme == .silhouetteCat || theme == .onelineCat }

    func body(content: Content) -> some View {
        if showsCat {
            content
                .miraCard(palette, padding: padding)
                .background(alignment: .topTrailing) {
                    head
                        .frame(width: 56, height: 32, alignment: .bottom)
                        .offset(y: hasAppeared || reduceMotion ? -24 : -18)
                        .padding(.trailing, 32)
                        .accessibilityHidden(true)
                        .allowsHitTesting(false)
                }
                .overlay(alignment: .topTrailing) {
                    HStack(spacing: 24) {
                        paw
                        paw
                    }
                    .frame(width: 56)
                    .padding(.trailing, 32)
                    .offset(y: -2)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
                }
                .padding(.top, 28)
                .onAppear {
                    // One small arrival, never a repeating attention animation.
                    withAnimation(reduceMotion ? nil : MiraMotion.gentle) {
                        hasAppeared = true
                    }
                }
        } else {
            content.miraCard(palette, padding: padding)
        }
    }

    @ViewBuilder
    private var head: some View {
        if theme == .silhouetteCat {
            Image("SilhouetteCatPeeking")
                .resizable()
                .scaledToFit()
        } else {
            ZStack {
                PeekingCatHead()
                    .fill(palette.surface)
                PeekingCatHead()
                    .stroke(palette.primaryText, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                HStack(spacing: 12) {
                    Capsule().frame(width: 3, height: 2.5)
                    Capsule().frame(width: 3, height: 2.5)
                }
                .foregroundStyle(palette.primaryText)
                .offset(y: 5)
            }
            .padding(.horizontal, 5)
        }
    }

    private var paw: some View {
        Capsule()
            .fill(theme == .silhouetteCat ? Color(hex: 0xC7BAC2) : palette.surface)
            .overlay {
                if theme == .onelineCat {
                    Capsule().strokeBorder(palette.primaryText, lineWidth: 2)
                }
            }
            .frame(width: 9, height: 7)
    }
}

private struct PeekingCatHead: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
        }
        path.move(to: point(0.08, 1))
        path.addQuadCurve(to: point(0.08, 0.48), control: point(0, 0.72))
        path.addLine(to: point(0.10, 0.09))
        path.addQuadCurve(to: point(0.19, 0.06), control: point(0.11, 0))
        path.addLine(to: point(0.35, 0.29))
        path.addQuadCurve(to: point(0.65, 0.29), control: point(0.50, 0.24))
        path.addLine(to: point(0.81, 0.06))
        path.addQuadCurve(to: point(0.90, 0.09), control: point(0.89, 0))
        path.addLine(to: point(0.92, 0.48))
        path.addQuadCurve(to: point(0.92, 1), control: point(1, 0.72))
        path.closeSubpath()
        return path
    }
}

extension View {
    func miraPeekingCatCard(_ palette: MiraThemePalette, theme: AppThemeKind, padding: CGFloat = MiraSpacing.md) -> some View {
        modifier(MiraPeekingCatCardModifier(palette: palette, theme: theme, padding: padding))
    }
}
