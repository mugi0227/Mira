import SwiftUI

struct PendingInvitationDetailSheet: View {
    @Environment(MiraStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let invitation: PendingInvitationEntity
    let palette: MiraThemePalette

    @State private var preparedEvent: CalendarItemSnapshot?
    @State private var impact: ScheduleImpact = .none
    @State private var conflicts: [String] = []
    @State private var worsenedGoalDeficits: [MarginKind: Int] = [:]
    @State private var isAnalyzing = false
    @State private var showAcceptOptions = false
    @State private var showDeclineDraft = false
    @State private var showConversationHistory = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: MiraSpacing.lg) {
                    header
                    candidateCard
                    impactCard
                    actions
                    if invitation.conversationCaseID != nil {
                        Button {
                            showConversationHistory = true
                        } label: {
                            Label("この誘いの会話を見る", systemImage: "bubble.left.and.bubble.right")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.bordered)
                        .tint(palette.accent)
                    }
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
            .confirmationDialog(reviewTitle, isPresented: $showAcceptOptions, titleVisibility: .visible) {
                ForEach(impact.relocationCandidates.prefix(3), id: \.self) { date in
                    Button("余白を \(date.japaneseShortDate) へ移して参加") {
                        commit(resolution: .relocate, relocation: date)
                    }
                }
                Button(impact.protectionLevel == .finalDefense ? "今回は例外として参加" : "このまま参加する") {
                    commit(resolution: .exception, relocation: nil)
                }
                Button("日程を調整する") {
                    store.convertPendingToAdjustment(invitation)
                    dismiss()
                }
                Button("いったん戻る", role: .cancel) {}
            } message: {
                Text(reviewMessage)
            }
            .sheet(isPresented: $showDeclineDraft) {
                DeclineDraftSheet(palette: palette)
            }
            .sheet(isPresented: $showConversationHistory) {
                ConversationHistorySheet(palette: palette, caseID: invitation.conversationCaseID)
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
                    Text(candidateDescription(candidate))
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
                Text("この予定を入れたときの生活への影響を確認中…")
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)
            }
            .frame(maxWidth: .infinity, minHeight: 72)
            .miraCard(palette)
        } else {
            VStack(alignment: .leading, spacing: MiraSpacing.sm) {
                Label(impactTitle, systemImage: impactSymbol)
                    .font(.headline)
                    .foregroundStyle(needsReview ? palette.warning : palette.success)

                Text(impactBody)
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(conflicts, id: \.self) { conflict in
                    Label(conflict, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(palette.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }

                ForEach(worsenedGoalDeficits.keys.sorted(by: { $0.defaultPriority > $1.defaultPriority }), id: \.self) { kind in
                    HStack {
                        Label(kind.title, systemImage: kind.symbolName)
                        Spacer()
                        Text("不足 \(worsenedGoalDeficits[kind] ?? 0)回")
                            .fontWeight(.semibold)
                    }
                    .font(.caption)
                    .foregroundStyle(palette.warning)
                }

                if let event = preparedEvent {
                    Divider()
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
                if needsReview {
                    showAcceptOptions = true
                } else {
                    commit(resolution: .exception, relocation: nil)
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

            Button {
                Task {
                    await store.prepareDeclineDraft(for: invitation)
                    showDeclineDraft = true
                }
            } label: {
                Label("断り文を作る", systemImage: "text.bubble")
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.bordered)
            .tint(palette.warning)

            Button(role: .destructive) {
                store.declinePending(invitation)
                dismiss()
            } label: {
                Text("文章は作らず、今回は見送る")
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.bordered)
            .tint(palette.critical)
        }
    }

    private var needsReview: Bool {
        !impact.overlappingMargins.isEmpty
            || impact.protectionLevel != .flexible
            || !conflicts.isEmpty
            || !worsenedGoalDeficits.isEmpty
    }

    private var impactTitle: String {
        if impact.protectionLevel == .finalDefense { return "このままだと大事な余白がなくなるにゃ" }
        if !conflicts.isEmpty { return "この予定、少し気になるところがあるにゃ" }
        if !worsenedGoalDeficits.isEmpty { return "今月の目標が少し遠のきそうだにゃ" }
        if !impact.overlappingMargins.isEmpty { return "移動したい余白があります" }
        return "今のところ大きな問題はなさそうにゃ"
    }

    private var impactBody: String {
        if needsReview {
            return "影響は見えるようにするけど、Miraが勝手に断ったり禁止したりはしないにゃ。日程調整か、このまま参加するかを選べます。"
        }
        return "余白・基本時間・ほかの予定・月の目標を見た限り、そのまま参加してもよさそうです。"
    }

    private var impactSymbol: String {
        needsReview ? "sparkles" : "checkmark.circle.fill"
    }

    private var reviewTitle: String {
        impact.protectionLevel == .finalDefense ? "最後の余白をどうする？" : "この予定、どうするにゃ？"
    }

    private var reviewMessage: String {
        var lines = conflicts
        if !worsenedGoalDeficits.isEmpty {
            lines.append(contentsOf: worsenedGoalDeficits.keys
                .sorted(by: { $0.defaultPriority > $1.defaultPriority })
                .prefix(2)
                .map { kind in "\(kind.title)があと\(worsenedGoalDeficits[kind] ?? 0)回不足する見込みです" })
        }
        if !impact.overlappingMargins.isEmpty {
            lines.append(impact.message)
        }
        lines.append("おすすめは示しますが、最終的にはあなたが選べます。")
        return lines.joined(separator: "\n")
    }

    @MainActor
    private func analyze() async {
        guard let candidate = invitation.candidates.first else { return }
        isAnalyzing = true
        var event = await store.prepareEvent(
            title: invitation.title,
            startDate: candidate.startDate,
            endDate: candidate.endDate,
            isAllDay: candidate.timeOfDay == .allDay,
            isImportant: false
        )
        event.schedulingTimeBand = candidate.displayTimeBand
        event.durationBucket = candidate.displayDuration
        event.exactTimeKnown = candidate.exactTimeKnown ?? true
        event.conversationCaseID = invitation.conversationCaseID
        preparedEvent = event
        impact = store.previewImpact(for: event)
        conflicts = store.eventEntryConflicts(for: event)
        worsenedGoalDeficits = store.worsenedGoalDeficits(afterAdding: event)
        isAnalyzing = false
    }

    private func commit(resolution: MiraStore.ImpactResolution, relocation: Date?) {
        guard let preparedEvent else { return }
        store.commitAdvisedEvent(
            preparedEvent,
            impact: impact,
            resolution: resolution,
            chosenRelocationDate: relocation
        )
        store.markPending(invitation, as: .accepted)
        dismiss()
    }

    private func candidateDescription(_ candidate: CandidateSlotSnapshot) -> String {
        if candidate.exactTimeKnown == false {
            return "\(candidate.displayTimeBand.title)・\(candidate.displayDuration.title)"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "H:mm"
        return "\(formatter.string(from: candidate.startDate))–\(formatter.string(from: candidate.endDate))"
    }
}
