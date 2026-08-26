import SwiftUI

struct AdjustmentsView: View {
    @Environment(MiraStore.self) private var store
    let palette: MiraThemePalette

    @State private var segment: AdjustmentSegment = .adjustments
    @State private var showCreate = false
    @State private var selectedAdjustment: AdjustmentEntity?
    @State private var selectedInvitation: PendingInvitationEntity?

    var body: some View {
        VStack(spacing: 0) {
            Picker("表示", selection: $segment) {
                ForEach(AdjustmentSegment.allCases) { segment in
                    Text(segment.title).tag(segment)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, MiraSpacing.md)
            .padding(.vertical, MiraSpacing.sm)

            ScrollView {
                LazyVStack(spacing: MiraSpacing.sm) {
                    if segment == .adjustments {
                        adjustmentList
                    } else {
                        invitationList
                    }
                }
                .padding(.horizontal, MiraSpacing.md)
                .padding(.bottom, 104)
            }
        }
        .background(palette.background)
        .navigationTitle("調整")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showCreate = true } label: {
                    Image(systemName: "plus")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(segment == .adjustments ? "日程調整を作成" : "検討中の誘いを追加")
            }
        }
        .sheet(isPresented: $showCreate) {
            if segment == .adjustments {
                NewAdjustmentSheet(palette: palette)
            } else {
                NewPendingInvitationSheet(palette: palette)
            }
        }
        .sheet(item: $selectedAdjustment) { session in
            AdjustmentDetailSheet(session: session, palette: palette)
        }
        .sheet(item: $selectedInvitation) { invitation in
            PendingInvitationDetailSheet(invitation: invitation, palette: palette)
        }
    }

    @ViewBuilder
    private var adjustmentList: some View {
        let active = store.adjustments.filter { $0.status != .cancelled }
        if active.isEmpty {
            EmptyStateView(
                symbol: "calendar.badge.plus",
                title: "調整中の日程はありません",
                message: "候補日を仮押さえして、ダブルブッキングを防げます。",
                palette: palette
            )
            .miraCard(palette)
            .padding(.top, MiraSpacing.lg)
        } else {
            ForEach(active, id: \.id) { session in
                Button { selectedAdjustment = session } label: {
                    AdjustmentRow(session: session, palette: palette)
                }
                .buttonStyle(MiraPressStyle())
            }
        }
    }

    @ViewBuilder
    private var invitationList: some View {
        let active = store.pendingInvitations.filter { [.considering, .adjustment].contains($0.status) }
        if active.isEmpty {
            EmptyStateView(
                symbol: "tray",
                title: "検討中の誘いはありません",
                message: "その場で返事せず、一度ここへ置いて余白への影響を見られます。",
                palette: palette
            )
            .miraCard(palette)
            .padding(.top, MiraSpacing.lg)
        } else {
            ForEach(active, id: \.id) { invitation in
                Button { selectedInvitation = invitation } label: {
                    PendingInvitationRow(invitation: invitation, palette: palette)
                }
                .buttonStyle(MiraPressStyle())
            }
        }
    }
}

private enum AdjustmentSegment: String, CaseIterable, Identifiable {
    case adjustments
    case pending

    var id: String { rawValue }
    var title: String { self == .adjustments ? "調整中" : "検討中" }
}

private struct AdjustmentRow: View {
    let session: AdjustmentEntity
    let palette: MiraThemePalette

    var body: some View {
        HStack(spacing: MiraSpacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: MiraRadius.small)
                    .fill(palette.adjustment)
                    .frame(width: 52, height: 52)
                Image(systemName: session.status == .confirmed ? "checkmark.calendar" : "calendar.badge.clock")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(palette.primaryText)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(session.title)
                    .font(.headline)
                    .foregroundStyle(palette.primaryText)
                Text("候補 \(session.candidates.filter { $0.status == .held }.count)件" + contactSuffix)
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
                if let deadline = session.responseDeadline {
                    Label("返事期限 \(deadline.japaneseShortDate)", systemImage: "bell")
                        .font(.caption2)
                        .foregroundStyle(palette.warning)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(palette.secondaryText)
        }
        .miraCard(palette, padding: MiraSpacing.sm)
        .accessibilityElement(children: .combine)
    }

    private var contactSuffix: String {
        guard let name = session.contactName, !name.isEmpty else { return "" }
        return "・\(name)"
    }
}

private struct PendingInvitationRow: View {
    let invitation: PendingInvitationEntity
    let palette: MiraThemePalette

    var body: some View {
        HStack(spacing: MiraSpacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: MiraRadius.small)
                    .fill(palette.pending)
                    .frame(width: 52, height: 52)
                Image(systemName: "questionmark.bubble.fill")
                    .font(.title3)
                    .foregroundStyle(palette.primaryText)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(invitation.title)
                    .font(.headline)
                    .foregroundStyle(palette.primaryText)
                Text(invitation.candidates.first?.startDate.japaneseShortDate ?? "日付未定")
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
                if let deadline = invitation.replyDeadline {
                    Text("返事は \(deadline.japaneseShortDate) まで")
                        .font(.caption2)
                        .foregroundStyle(palette.warning)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(palette.secondaryText)
        }
        .miraCard(palette, padding: MiraSpacing.sm)
        .accessibilityElement(children: .combine)
    }
}
