import SwiftUI

struct AdjustmentsView: View {
    @Environment(MiraStore.self) private var store
    let palette: MiraThemePalette

    @State private var segment: AdjustmentSegment = .adjustments
    @State private var showPendingCreate = false
    @State private var selectedAdjustment: AdjustmentEntity?
    @State private var selectedInvitation: PendingInvitationEntity?

    var body: some View {
        VStack(spacing: 0) {
            if palette.isCatSkin {
                HStack(spacing: MiraSpacing.md) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("会いたい時間を、心地よく")
                            .font(.title3.bold())
                            .foregroundStyle(palette.primaryText)
                        Text("日程も、返事待ちも、ここでひと息。")
                            .font(.subheadline)
                            .foregroundStyle(palette.secondaryText)
                    }
                    Spacer(minLength: 0)
                    MiraBotanicalAccent(palette: palette)
                        .frame(width: 48, height: 60)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, MiraSpacing.lg)
                .padding(.top, MiraSpacing.sm)
            }

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
                        manualSchedulingCard
                        adjustmentList
                    } else {
                        invitationList
                    }
                }
                .padding(.horizontal, MiraSpacing.md)
                .padding(.bottom, 104)
            }
        }
        .miraScreenBackground(palette)
        .navigationTitle("調整")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if segment == .adjustments {
                        store.startManualScheduling()
                    } else {
                        showPendingCreate = true
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(palette.isCatSkin ? .body.weight(.semibold) : .body)
                        .foregroundStyle(palette.isCatSkin ? palette.onAccent : palette.accent)
                        .frame(width: 44, height: 44)
                        .background {
                            if palette.isCatSkin {
                                Circle().fill(palette.actionGradient)
                            }
                        }
                }
                .accessibilityLabel(segment == .adjustments ? "日程を探す" : "検討中の誘いを追加")
            }
        }
        .sheet(isPresented: $showPendingCreate) {
            NewPendingInvitationSheet(palette: palette)
        }
        .sheet(item: $selectedAdjustment) { session in
            AdjustmentDetailSheet(session: session, palette: palette)
        }
        .sheet(item: $selectedInvitation) { invitation in
            PendingInvitationDetailSheet(invitation: invitation, palette: palette)
        }
    }

    private var manualSchedulingCard: some View {
        Button {
            store.startManualScheduling()
        } label: {
            HStack(spacing: MiraSpacing.sm) {
                Image(systemName: "calendar.badge.plus")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(palette.accent)
                    .frame(width: 48, height: 48)
                    .background(palette.accentSoft, in: RoundedRectangle(cornerRadius: palette.isCatSkin ? 24 : MiraRadius.small))
                VStack(alignment: .leading, spacing: 4) {
                    Text("新しい日程を探す")
                        .font(.headline)
                        .foregroundStyle(palette.primaryText)
                    Text("Miraが良い候補を先に選び、カレンダー上で追加・削除できます。")
                        .font(.caption)
                        .foregroundStyle(palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(palette.secondaryText)
            }
            .miraCard(palette, padding: palette.isCatSkin ? MiraSpacing.md : MiraSpacing.sm)
        }
        .buttonStyle(MiraPressStyle())
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
            .padding(.top, MiraSpacing.sm)
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
        let active = store.pendingInvitations.filter { $0.status == .considering }
        if active.isEmpty {
            EmptyStateView(
                symbol: "tray",
                title: "検討中の誘いはありません",
                message: "LINEの文章をホームへ貼るか、＋から誘いを一度ここへ置けます。",
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
                } else if session.status == .waiting {
                    Text("返事待ち・候補を仮押さえ中")
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
