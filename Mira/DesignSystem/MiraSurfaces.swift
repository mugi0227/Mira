import SwiftUI

/// The same sky treatment follows the cat skin into pushed screens and sheets.
struct MiraScreenBackground: View {
    let palette: MiraThemePalette

    var body: some View {
        palette.backgroundGradient
            .overlay(alignment: .topTrailing) {
                if palette.isCatSkin {
                    Circle()
                        .fill(palette.surface.opacity(0.28))
                        .frame(width: 280, height: 280)
                        .blur(radius: 40)
                        .offset(x: 90, y: -100)
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

private struct MiraScreenModifier: ViewModifier {
    let palette: MiraThemePalette

    @ViewBuilder
    func body(content: Content) -> some View {
        if palette.isCatSkin {
            content
                .scrollContentBackground(.hidden)
                .background { MiraScreenBackground(palette: palette) }
                .toolbarBackground(.hidden, for: .navigationBar)
                .tint(palette.accent)
                .foregroundStyle(palette.primaryText)
        } else {
            content.background(palette.background)
        }
    }
}

private struct MiraFormModifier: ViewModifier {
    let palette: MiraThemePalette

    @ViewBuilder
    func body(content: Content) -> some View {
        if palette.isCatSkin {
            content
                .scrollContentBackground(.hidden)
                .listRowBackground(palette.surface)
                .listSectionSpacing(MiraSpacing.md)
                .miraScreenBackground(palette)
        } else {
            content
        }
    }
}

extension View {
    func miraScreenBackground(_ palette: MiraThemePalette) -> some View {
        modifier(MiraScreenModifier(palette: palette))
    }

    func miraFormStyle(_ palette: MiraThemePalette) -> some View {
        modifier(MiraFormModifier(palette: palette))
    }
}

/// Small vector sprigs keep the decoration crisp at every text and display scale.
struct MiraBotanicalAccent: View {
    let palette: MiraThemePalette

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            var stem = Path()
            stem.move(to: CGPoint(x: w * 0.45, y: h))
            stem.addQuadCurve(
                to: CGPoint(x: w * 0.62, y: h * 0.12),
                control: CGPoint(x: w * 0.32, y: h * 0.55)
            )
            context.stroke(stem, with: .color(palette.botanical.opacity(0.6)), lineWidth: 1.5)

            let leaves: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
                (0.46, 0.82, 0.08, 0.59), (0.46, 0.73, 0.93, 0.49),
                (0.48, 0.57, 0.20, 0.28), (0.52, 0.46, 0.85, 0.13),
                (0.59, 0.25, 0.56, 0.01)
            ]
            for (x, y, tipX, tipY) in leaves {
                let start = CGPoint(x: x * w, y: y * h)
                let tip = CGPoint(x: tipX * w, y: tipY * h)
                let dx = tip.x - start.x
                let dy = tip.y - start.y
                var leaf = Path()
                leaf.move(to: start)
                leaf.addQuadCurve(to: tip, control: CGPoint(
                    x: start.x + dx * 0.1 - dy * 0.36,
                    y: start.y + dy * 0.1 + dx * 0.36
                ))
                leaf.addQuadCurve(to: start, control: CGPoint(
                    x: start.x + dx * 0.8 + dy * 0.24,
                    y: start.y + dy * 0.8 - dx * 0.24
                ))
                context.fill(leaf, with: .color(palette.botanical.opacity(0.56)))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct MiraCompanionBackdrop: View {
    let palette: MiraThemePalette

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomTrailing) {
                Ellipse()
                    .fill(palette.accentSoft.opacity(0.5))
                    .frame(width: geometry.size.width * 0.52, height: geometry.size.height * 0.7)
                    .rotationEffect(.degrees(-24))
                    .offset(x: 46, y: 44)
                MiraBotanicalAccent(palette: palette)
                    .frame(width: 58, height: 82)
                    .padding(.trailing, 8)
                    .offset(y: 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
