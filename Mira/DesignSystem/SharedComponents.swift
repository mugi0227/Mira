import SwiftUI

struct PrimaryButton: View {
    let title: String
    let symbol: String?
    let palette: MiraThemePalette
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: MiraSpacing.xs) {
                if let symbol {
                    Image(systemName: symbol)
                        .accessibilityHidden(true)
                }
                Text(title)
                    .font(.headline.weight(.bold))
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .foregroundStyle(palette.onAccent)
            .background {
                if isDisabled {
                    palette.secondaryText.opacity(0.35)
                } else {
                    palette.actionGradient
                }
            }
            .clipShape(Capsule())
            .overlay {
                Capsule().strokeBorder(palette.cardBorder.opacity(0.65), lineWidth: 1)
            }
            .shadow(color: !isDisabled ? palette.shadow : .clear, radius: 10, y: 4)
        }
        .buttonStyle(MiraPressStyle())
        .disabled(isDisabled)
        .accessibilityLabel(title)
    }
}

struct ProgressPill: View {
    let symbol: String
    let title: String
    let current: Int
    let target: Int
    let palette: MiraThemePalette

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.caption.weight(.semibold))
                .accessibilityHidden(true)
            Text(title)
                .font(.caption.weight(.medium))
                .lineLimit(1)
            Text("\(current)/\(target)")
                .font(.caption.monospacedDigit().weight(.semibold))
        }
        .foregroundStyle(palette.primaryText)
        .padding(.horizontal, 8)
        .frame(minHeight: 36)
        .background(palette.goalTint(for: symbol), in: Capsule())
        .overlay {
            Capsule().strokeBorder(palette.cardBorder, lineWidth: 1.5)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title) \(current)回、目標\(target)回")
    }
}

struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String
    let palette: MiraThemePalette

    var body: some View {
        VStack(spacing: MiraSpacing.sm) {
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(palette.accent)
                .accessibilityHidden(true)
            Text(title)
                .font(.headline)
                .foregroundStyle(palette.primaryText)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(palette.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, MiraSpacing.xl)
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = MiraSpacing.xs

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        arrangement(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let result = arrangement(
            proposal: ProposedViewSize(width: bounds.width, height: proposal.height),
            subviews: subviews
        )
        for (index, point) in result.points.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y),
                anchor: .topLeading,
                proposal: .unspecified
            )
        }
    }

    private func arrangement(proposal: ProposedViewSize, subviews: Subviews) -> Arrangement {
        let maxWidth = proposal.width ?? .greatestFiniteMagnitude
        var points: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var usedWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            points.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            usedWidth = max(usedWidth, max(0, x - spacing))
        }

        return Arrangement(
            size: CGSize(width: min(maxWidth, usedWidth), height: y + rowHeight),
            points: points
        )
    }

    private struct Arrangement {
        var size: CGSize
        var points: [CGPoint]
    }
}

/// The app icon's 余白 meter ring, used as the Soft Minimal loading mark.
struct MiraRingMark: View {
    let palette: MiraThemePalette
    var size: CGFloat = 84
    var spins = true

    var body: some View {
        TimelineView(.animation(paused: !spins)) { context in
            let angle = spins ? context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2.4) / 2.4 * 360 : 0
            ZStack {
                Circle()
                    .stroke(palette.accentSoft, lineWidth: size * 0.16)
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(palette.accent, style: StrokeStyle(lineWidth: size * 0.16, lineCap: .round))
                    .rotationEffect(.degrees(angle - 90))
                Circle()
                    .fill(palette.accent.opacity(0.9))
                    .frame(width: size * 0.23, height: size * 0.23)
            }
            .padding(size * 0.08)
            .frame(width: size, height: size)
        }
        .accessibilityHidden(true)
    }
}
