import SwiftUI

struct PendingInvitationDetailSheet: View {
    @Environment(MiraStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let invitation: PendingInvitationEntity
    let palette: MiraThemePalette

    @State private var preparedEvent: CalendarItemSnapshot?
    @State private var impact: ScheduleImpact = .none
    @State private var isAnalyzing = false
    @State private var showAcceptOptions = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: MiraSpacing.lg) {
                    header
                    candidateCard
                    impactCard
                    actions
                }
                .padding(MiraSpacing.md)
                .padding(.bottom, MiraSpacing.xl)
            }
            .background(palette.background)
            .navigationTitle("検討中の誘い")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("閉じる") { dismiss() } }
            }
            .task { await analyze() }
            .confirmationDialog("余白をどうしますか？", isPresented: $showAcceptOptions, titleVisibility: .visible) {
                ForEach(impact.relocationCandidates.prefix(3), id: \.self) { date in
                    Button("余白を \(date.japaneseShortDate) へ移して参加") {
                        commit(resolution: .relocate, relocation: date)
                    }
                }
                Button("今回は例外として参加") {
                    commit(resolution: .exception, relocation: nil)
                }
                Button("やめる", role: .cancel) {}
            } message: {
                Text(impact.message)
            }
        }
        .tint(palette.accent)
    }

    private var header: some View {
        HStack(spacing: MiraSpacing.md) {
            if store.theme == .pixelCat {
                PixelCatView(mood: .thinking, size: 76)
            } else {
                Image(systemName: "questionmark.bubble.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(palette.accent)
                    .frame(width: 76)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(invitation.title)
                    .font(.title2.bold())
                    .foregroundStyle(palette.primaryText)
                if let contact = invitation.contactName {
                    Text(contact)
                        .font(.subheadline)
                        .foregroundStyle(palette.secondaryText)
                }
                Text("まだ返事していない予定")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.warning)
            }
            Spacer(minLength: 0)
        }
        .miraCard(palette)
    }

    private var candidateCard: some View {
        VStack(alignment: .leading, spacing: MiraSpacing.sm) {
            Label("候補日時", systemImage: "calendar")
                .font(.headline)
            ForEach(invitation.candidates) { candidate in
                HStack {
                    Text(candidate.startDate.japaneseDayTitle)
                    Spacer()
                    Text(candidate.timeOfDay.title)
                        .foregroundStyle(palette.secondaryText)
                }
                .font(.subheadline)
            }
            if let deadline = invitation.replyDeadline {
                Divider()
                Label("返事期限 \(deadline.japaneseShortDate)", systemImage: "bell")
                    .font(.caption)
                    .foregroundStyle(palette.warning)
            }
        }
        .foregroundStyle(palette.primaryText)
        .miraCard(palette)
    }

    @ViewBuilder
    private var impactCard: some View {
        if isAnalyzing {
            HStack(spacing: MiraSpacing.sm) {
                ProgressView()
                Text("この予定を入れたときの余白を確認中…")
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)
            }
            .frame(maxWidth: .infinity, minHeight: 72)
            .miraCard(palette)
        } else {
            VStack(alignment: .leading, spacing: MiraSpacing.sm) {
                Label(impactTitle, systemImage: impact.overlappingMargins.isEmpty ? "checkmark.circle.fill" : "leaf.fill")
                    .font(.headline)
                    .foregroundStyle(impact.overlappingMargins.isEmpty ? palette.success : palette.warning)
                Text(impact.message)
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)
                if let event = preparedEvent {
                    HStack {
                        Text("推定負荷")
                        Spacer()
                        Text(event.loadClass.title)
                            .fontWeight(.semibold)
                    }
                    .font(.caption)
                    .foregroundStyle(palette.primaryText)
                }
            }
            .miraCard(palette)
        }
    }

    private var actions: some View {
        VStack(spacing: MiraSpacing.sm) {
            PrimaryButton(title: "参加する", symbol: "checkmark", palette: palette, isDisabled: preparedEvent == nil) {
                if impact.overlappingMargins.isEmpty {
                    commit(resolution: .exception, relocation: nil)
                } else {
                    showAcceptOptions = true
                }
            }

            Button {
                store.convertPendingToAdjustment(invitation)
                dismiss()
            } label: {
                Label("日程を調整する", systemImage: "calendar.badge.clock")
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.bordered)
            .tint(palette.accent)

            Button(role: .destructive) {
                store.declinePending(invitation)
                dismiss()
            } label: {
                Text("今回は見送る")
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.bordered)
            .tint(palette.critical)
        }
    }

    private var impactTitle: String {
        impact.overlappingMargins.isEmpty ? "余白を守ったまま参加できます" : "移動したい余白があります"
    }

    @MainActor
    private func analyze() async {
        guard let candidate = invitation.candidates.first else { return }
        isAnalyzing = true
        let event = await store.prepareEvent(
            title: invitation.title,
            startDate: candidate.startDate,
            endDate: candidate.endDate,
            isAllDay: candidate.timeOfDay == .allDay,
            isImportant: false
        )
        preparedEvent = event
        impact = store.previewImpact(for: event)
        isAnalyzing = false
    }

    private func commit(resolution: MiraStore.ImpactResolution, relocation: Date?) {
        guard let preparedEvent else { return }
        store.commitEvent(
            preparedEvent,
            impact: impact,
            resolution: resolution,
            chosenRelocationDate: relocation
        )
        store.markPending(invitation, as: .accepted)
        dismiss()
    }
}
