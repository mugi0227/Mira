import SwiftUI
import UIKit

struct AdjustmentDetailSheet: View {
    @Environment(MiraStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let session: AdjustmentEntity
    let palette: MiraThemePalette

    @State private var showCancelConfirmation = false
    @State private var showConversationHistory = false
    @State private var confirmationReview: CandidateConfirmationReview?
    @State private var showCandidateReview = false
    @State private var isPreparingConfirmation = false
    @State private var showDeadlineEditor = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: MiraSpacing.lg) {
                    statusHeader
                    candidateSection
                    sharingCard
                    if session.status == .draft || session.status == .waiting {
                        deadlineCard
                    }
                    if session.conversationCaseID != nil {
                        Button {
                            showConversationHistory = true
                        } label: {
                            Label("この調整の会話を見る", systemImage: "bubble.left.and.bubble.right")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.bordered)
                        .tint(palette.accent)
                    }
                    if session.status == .draft || session.status == .waiting {
                        cancelButton
                    }
                }
                .padding(MiraSpacing.md)
                .padding(.bottom, MiraSpacing.xl)
            }
            .miraScreenBackground(palette)
            .navigationTitle("日程調整")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("閉じる") { dismiss() } }
            }
            .confirmationDialog("登録すると変わること", isPresented: $showCandidateReview, titleVisibility: .visible) {
                if let review = confirmationReview {
                    ForEach(review.impact.relocationCandidates.prefix(2), id: \.self) { date in
                        Button("余白を \(date.japaneseShortDate) へ移して確定") {
                            commit(review, resolution: .relocate, relocation: date)
                        }
                    }
                    Button(review.needsException ? "影響を承認して、この日で確定" : "この日で確定") {
                        commit(review, resolution: .exception, relocation: nil)
                    }
                }
                Button("いったん戻る", role: .cancel) {}
            } message: {
                if let review = confirmationReview {
                    Text("\(review.candidate.startDate.japaneseShortDate) \(candidateDescription(review.candidate))\n\n\(review.summary)")
                }
            }
            .confirmationDialog("調整を取りやめますか？", isPresented: $showCancelConfirmation) {
                Button("候補日をすべて解放", role: .destructive) {
                    Task {
                        if await store.cancelAdjustment(session) { dismiss() }
                    }
                }
                Button("やめる", role: .cancel) {}
            }
            .sheet(isPresented: $showConversationHistory) {
                ConversationHistorySheet(palette: palette, caseID: session.conversationCaseID)
            }
            .sheet(isPresented: $showDeadlineEditor) {
                AdjustmentDeadlineEditor(session: session, palette: palette)
            }
            .overlay {
                if isPreparingConfirmation {
                    ProgressView("最新の予定と余白を確認中")
                        .padding(MiraSpacing.lg)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: MiraRadius.medium))
                }
            }
        }
        .tint(palette.accent)
    }

    private var statusHeader: some View {
        HStack(spacing: MiraSpacing.md) {
            if store.theme == .pixelCat {
                PixelCatView(mood: session.status == .confirmed ? .celebrating : .thinking, size: 78)
            } else {
                Image(systemName: session.status == .confirmed ? "checkmark.circle.fill" : "calendar.badge.clock")
                    .font(.system(size: 44))
                    .foregroundStyle(session.status == .confirmed ? palette.success : palette.accent)
                    .frame(width: 78)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(session.title)
                    .font(.title2.bold())
                    .foregroundStyle(palette.primaryText)
                if let contact = session.contactName {
                    Text(contact)
                        .font(.subheadline)
                        .foregroundStyle(palette.secondaryText)
                }
                Text(statusText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(session.status == .confirmed ? palette.success : palette.warning)
            }
            Spacer(minLength: 0)
        }
        .miraCard(palette)
    }

    private var candidateSection: some View {
        VStack(alignment: .leading, spacing: MiraSpacing.sm) {
            Text("候補日")
                .font(.title3.bold())
                .foregroundStyle(palette.primaryText)

            if session.candidates.isEmpty {
                VStack(alignment: .leading, spacing: MiraSpacing.sm) {
                    Text("候補日はまだありません")
                        .font(.subheadline)
                        .foregroundStyle(palette.secondaryText)
                    Button {
                        store.startScheduling(for: session)
                        dismiss()
                    } label: {
                        Label("候補日を探す", systemImage: "calendar.badge.plus")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(palette.accent)
                }
                .miraCard(palette, padding: MiraSpacing.sm)
            }

            ForEach(session.candidates) { candidate in
                let conflicts = store.conflictMessages(for: candidate, excluding: session.id)
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: MiraSpacing.sm) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(candidate.status == .confirmed ? palette.success.opacity(0.18) : palette.adjustment)
                                .frame(width: 48, height: 48)
                            Image(systemName: candidate.status == .confirmed ? "checkmark" : candidate.displayTimeBand.symbolName)
                                .font(.headline)
                                .foregroundStyle(candidate.status == .confirmed ? palette.success : palette.primaryText)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(candidate.startDate.japaneseDayTitle)
                                .font(.headline)
                                .foregroundStyle(palette.primaryText)
                            Text(candidateDescription(candidate))
                                .font(.caption)
                                .foregroundStyle(palette.secondaryText)
                        }
                        Spacer()
                        if session.status == .draft || session.status == .waiting, candidate.status == .held {
                            Button("確定") { prepareConfirmation(candidate) }
                                .font(.subheadline.weight(.semibold))
                                .buttonStyle(.borderedProminent)
                                .tint(palette.accent)
                                .frame(minHeight: 44)
                                .disabled(isPreparingConfirmation)
                        } else {
                            Text(candidateStatus(candidate.status))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(candidate.status == .confirmed ? palette.success : palette.secondaryText)
                        }
                    }

                    if candidate.isRecommended == true {
                        Label("Miraのおすすめ", systemImage: "sparkles")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(palette.accent)
                    }

                    if !conflicts.isEmpty, candidate.status == .held {
                        ForEach(conflicts, id: \.self) { conflict in
                            Label(conflict, systemImage: conflict.contains("余白") ? "leaf.fill" : "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(conflict.contains("余白") ? palette.success : palette.warning)
                        }
                    }
                }
                .miraCard(palette, padding: MiraSpacing.sm)
            }
        }
    }

    private var sharingCard: some View {
        Group {
            if session.candidates.isEmpty || session.status == .confirmed || session.status == .cancelled {
                EmptyView()
            } else {
                VStack(alignment: .leading, spacing: MiraSpacing.sm) {
                    Label("送る文章", systemImage: "message")
                        .font(.headline)
                        .foregroundStyle(palette.primaryText)
                    Text(session.generatedMessage)
                        .font(.subheadline)
                        .foregroundStyle(palette.secondaryText)
                        .textSelection(.enabled)
                    HStack(spacing: MiraSpacing.sm) {
                        Button {
                            UIPasteboard.general.string = session.generatedMessage
                            store.toast = "文章をコピーしたにゃ"
                        } label: {
                            Label("コピー", systemImage: "doc.on.doc")
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.bordered)

                        ShareLink(item: session.generatedMessage) {
                            Label("共有", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .tint(palette.accent)

                    if session.status == .draft {
                        Text("コピーや共有だけでは送信済みにしません。相手へ送った後で記録できます。")
                            .font(.caption)
                            .foregroundStyle(palette.secondaryText)
                        PrimaryButton(title: "相手へ送った・返事待ちにする", symbol: "paperplane.fill", palette: palette) {
                            Task { await store.markAdjustmentSent(session) }
                        }
                    } else if session.status == .waiting {
                        Button("まだ送っていない状態へ戻す") {
                            Task { await store.markAdjustmentUnsent(session) }
                        }
                        .font(.caption)
                        .frame(minHeight: 44)
                    }
                }
                .miraCard(palette)
            }
        }
    }

    private var cancelButton: some View {
        Button(role: .destructive) {
            showCancelConfirmation = true
        } label: {
            Label("調整を取りやめる", systemImage: "xmark.circle")
                .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(.bordered)
        .tint(palette.critical)
    }

    private var statusText: String {
        switch session.status {
        case .draft: "送る準備・まだ相手へ送っていません"
        case .waiting: "返事待ち・候補日をゆるく仮押さえ中"
        case .confirmed: "日程確定済み"
        case .cancelled: "キャンセル済み"
        }
    }

    private var deadlineCard: some View {
        Button { showDeadlineEditor = true } label: {
            HStack {
                Label("返事を確認する期限", systemImage: "bell")
                Spacer()
                Text(session.responseDeadline?.japaneseShortDate ?? "設定しない")
                Image(systemName: "chevron.right")
            }
            .font(.subheadline)
            .frame(minHeight: 44)
            .miraCard(palette)
        }
        .buttonStyle(.plain)
        .foregroundStyle(palette.primaryText)
    }

    private func prepareConfirmation(_ candidate: CandidateSlotSnapshot) {
        isPreparingConfirmation = true
        Task {
            confirmationReview = await store.prepareCandidateConfirmation(sessionID: session.id, candidateID: candidate.id)
            isPreparingConfirmation = false
            showCandidateReview = confirmationReview != nil
        }
    }

    private func commit(_ review: CandidateConfirmationReview, resolution: MiraStore.ImpactResolution, relocation: Date?) {
        isPreparingConfirmation = true
        Task {
            let saved = await store.confirmCandidate(
                sessionID: session.id,
                candidateID: review.candidate.id,
                approval: review,
                resolution: resolution,
                chosenRelocationDate: relocation
            )
            isPreparingConfirmation = false
            if saved {
                dismiss()
            } else {
                prepareConfirmation(review.candidate)
            }
        }
    }

    private func candidateDescription(_ candidate: CandidateSlotSnapshot) -> String {
        if candidate.exactTimeKnown == false {
            return "\(candidate.displayTimeBand.title)・\(candidate.displayDuration.title)・時間未定"
        }
        let formatter = DateFormatter.mira("H:mm")
        return "\(formatter.string(from: candidate.startDate))–\(formatter.string(from: candidate.endDate))"
    }

    private func candidateStatus(_ status: CandidateStatus) -> String {
        switch status {
        case .held: "仮押さえ"
        case .confirmed: "確定"
        case .released: "解放済み"
        }
    }
}

private struct AdjustmentDeadlineEditor: View {
    @Environment(MiraStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let session: AdjustmentEntity
    let palette: MiraThemePalette
    @State private var enabled: Bool
    @State private var deadline: Date

    init(session: AdjustmentEntity, palette: MiraThemePalette) {
        self.session = session
        self.palette = palette
        _enabled = State(initialValue: session.responseDeadline != nil)
        _deadline = State(initialValue: session.responseDeadline ?? Date().addingTimeInterval(2 * 86_400))
    }

    var body: some View {
        NavigationStack {
            Form {
                Toggle("期限を設定する", isOn: $enabled)
                if enabled {
                    DatePicker("期限", selection: $deadline, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                }
                Text("送信済みにした調整だけ通知します。期限を変えると通知も更新します。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("返事の確認期限")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("閉じる") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task {
                            if await store.updateAdjustmentDeadline(session, deadline: enabled ? deadline : nil) { dismiss() }
                        }
                    }
                }
            }
        }
        .tint(palette.accent)
    }
}
