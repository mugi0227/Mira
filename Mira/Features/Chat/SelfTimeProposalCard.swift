import SwiftUI

/// A suggestion for the person's own time inside the chat. Every slot is a
/// chip that can be switched off; nothing is placed until the button is tapped.
struct SelfTimeProposalCard: View {
    @Environment(MiraStore.self) private var store
    let proposal: ChatSelfTimeProposal
    let messageID: UUID
    let palette: MiraThemePalette

    private static let dayFormatter = DateFormatter.mira("M/d(E)")
    private static let timeFormatter = DateFormatter.mira("H:mm")

    private var isPending: Bool { proposal.state == .pending }

    var body: some View {
        VStack(alignment: .leading, spacing: MiraSpacing.sm) {
            badges
            headline
            ChipFlowLayout(spacing: MiraSpacing.xs) {
                ForEach(proposal.suggestion.margins) { margin in
                    slotChip(margin)
                }
            }
            Label(proposal.suggestion.reason, systemImage: "text.quote")
                .font(.caption)
                .foregroundStyle(palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            actions
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("selfTimeProposal")
    }

    // MARK: Parts

    private var badges: some View {
        HStack(spacing: 6) {
            badge(
                proposal.suggestion.origin == .proactive ? "Miraから" : "あなたのお願い",
                symbol: proposal.suggestion.origin == .proactive ? "bell.badge.fill" : "sparkles",
                tint: palette.accent
            )
            if proposal.suggestion.usesTrend {
                badge("最近の傾向から", symbol: "chart.line.uptrend.xyaxis", tint: palette.success)
                    .accessibilityIdentifier("selfTimeTrendBadge")
            }
        }
    }

    private func badge(_ title: String, symbol: String, tint: Color) -> some View {
        Label(title, systemImage: symbol)
            .font(.caption2.weight(.bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.13), in: Capsule())
    }

    private var headline: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("+\(hoursText(isPending ? proposal.chosenHours : appliedOrAllHours))")
                .font(.system(.title, design: .rounded).weight(.bold))
                .foregroundStyle(palette.primaryText)
                .contentTransition(.numericText())
            Text("時間")
                .font(.headline)
                .foregroundStyle(palette.primaryText)
            Text(weekTitle)
                .font(.subheadline)
                .foregroundStyle(palette.secondaryText)
        }
        .accessibilityElement(children: .combine)
    }

    private func slotChip(_ margin: SuggestedMargin) -> some View {
        let included = !proposal.excludedMarginIDs.contains(margin.id)
        let label = "\(Self.dayFormatter.string(from: margin.startDate)) \(Self.timeFormatter.string(from: margin.startDate))–\(Self.timeFormatter.string(from: margin.endDate))"
        return Button {
            withAnimation(MiraMotion.quick) {
                store.toggleSelfTimeSlot(messageID: messageID, proposal: proposal, marginID: margin.id)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: included ? margin.kind.symbolName : "circle.dashed")
                    .font(.caption.weight(.bold))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 0) {
                    Text(Self.dayFormatter.string(from: margin.startDate))
                        .font(.subheadline.weight(.bold))
                    Text("\(Self.timeFormatter.string(from: margin.startDate))–\(Self.timeFormatter.string(from: margin.endDate))")
                        .font(.caption.monospacedDigit())
                }
                .strikethrough(!included)
            }
            .foregroundStyle(included ? palette.onAccent : palette.secondaryText)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .frame(minHeight: 44)
            .background {
                Capsule().fill(included ? palette.accent : palette.surface)
            }
            .overlay {
                Capsule().strokeBorder(included ? Color.clear : palette.secondaryText.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
        }
        .buttonStyle(MiraPressStyle())
        .disabled(!isPending)
        .accessibilityLabel("\(label) \(margin.kind.shortTitle)")
        .accessibilityValue(included ? "置く" : "外した")
        .accessibilityAddTraits(included ? .isSelected : [])
        .accessibilityIdentifier("selfTimeSlotChip")
    }

    @ViewBuilder
    private var actions: some View {
        switch proposal.state {
        case .pending:
            let count = proposal.chosenMargins.count
            HStack(spacing: MiraSpacing.xs) {
                Button {
                    withAnimation(MiraMotion.standard) {
                        _ = store.applySelfTimeCard(messageID: messageID, proposal: proposal)
                    }
                } label: {
                    Label(count == 0 ? "枠を選んでね" : "この\(count)枠を置く", systemImage: "leaf.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(palette.onAccent)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(count == 0 ? palette.secondaryText.opacity(0.35) : palette.accent, in: Capsule())
                }
                .buttonStyle(MiraPressStyle())
                .disabled(count == 0)
                .accessibilityIdentifier("selfTimeApply")

                Button("今回は見送る") {
                    withAnimation(MiraMotion.standard) {
                        store.dismissSelfTimeCard(messageID: messageID, proposal: proposal)
                    }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.secondaryText)
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .background(palette.surface, in: Capsule())
                .overlay { Capsule().strokeBorder(palette.secondaryText.opacity(0.2), lineWidth: 1) }
                .buttonStyle(MiraPressStyle())
                .accessibilityIdentifier("selfTimeDismiss")
            }
        case .applied:
            HStack(spacing: MiraSpacing.xs) {
                statusChip("置きました", symbol: "checkmark.circle.fill", tint: palette.success)
                Button {
                    withAnimation(MiraMotion.standard) {
                        store.undoSelfTimeCard(messageID: messageID, proposal: proposal)
                    }
                } label: {
                    Label("取り消す", systemImage: "arrow.uturn.backward")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.accent)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                        .background(palette.accentSoft, in: Capsule())
                }
                .buttonStyle(MiraPressStyle())
                .accessibilityIdentifier("selfTimeUndo")
            }
        case .dismissed:
            statusChip("見送りました", symbol: "xmark.circle", tint: palette.secondaryText)
        case .undone:
            statusChip("取り消しました", symbol: "arrow.uturn.backward.circle", tint: palette.secondaryText)
        }
    }

    private func statusChip(_ title: String, symbol: String, tint: Color) -> some View {
        Label(title, systemImage: symbol)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(tint.opacity(0.12), in: Capsule())
    }

    // MARK: Text

    private var appliedOrAllHours: Double {
        let applied = proposal.suggestion.margins.filter { proposal.appliedMarginIDs.contains($0.id) }
        return (applied.isEmpty ? proposal.chosenMargins : applied).reduce(0) { $0 + $1.hours }
    }

    private var weekTitle: String {
        let week = WeekKey(containing: store.now)
        if proposal.suggestion.weekStart == week.start { return "今週の自分の時間" }
        if proposal.suggestion.weekStart == week.adding(weeks: 1).start { return "来週の自分の時間" }
        return "\(Self.dayFormatter.string(from: proposal.suggestion.weekStart))からの週"
    }

    private func hoursText(_ hours: Double) -> String {
        hours.rounded() == hours ? "\(Int(hours))" : String(format: "%.1f", hours)
    }
}

/// Lays chips out in rows, wrapping to the next line when a row is full.
struct ChipFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = rows[rows.count - 1].indices.isEmpty ? size.width : rows[rows.count - 1].width + spacing + size.width
            if needed > width, !rows[rows.count - 1].indices.isEmpty {
                rows.append(Row())
            }
            var row = rows[rows.count - 1]
            row.width = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            row.height = max(row.height, size.height)
            row.indices.append(index)
            rows[rows.count - 1] = row
        }
        return rows.filter { !$0.indices.isEmpty }
    }
}
