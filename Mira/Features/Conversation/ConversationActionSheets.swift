import SwiftUI
import UIKit

struct ConversationClarificationSheet: View {
    @Environment(MiraStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let palette: MiraThemePalette

    var body: some View {
        NavigationStack {
            VStack(spacing: MiraSpacing.lg) {
                PixelCatView(mood: .thinking, size: 92)
                Text(store.activeClarification?.question ?? "もう少し教えてにゃ")
                    .font(.title2.bold())
                    .foregroundStyle(palette.primaryText)
                    .multilineTextAlignment(.center)

                VStack(spacing: MiraSpacing.sm) {
                    ForEach(store.activeClarification?.options ?? [], id: \.self) { option in
                        PrimaryButton(title: option, symbol: nil, palette: palette) {
                            dismiss()
                            Task { await store.answerClarification(option) }
                        }
                    }
                }
                Spacer()
            }
            .padding(MiraSpacing.lg)
            .miraScreenBackground(palette)
            .navigationTitle("Miraから確認")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        store.activeClarification = nil
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .tint(palette.accent)
    }
}

struct DeclineDraftSheet: View {
    @Environment(MiraStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let palette: MiraThemePalette

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: MiraSpacing.lg) {
                    HStack(spacing: MiraSpacing.md) {
                        PixelCatView(mood: .thinking, size: 74)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("嘘をつかずに、やわらかく断るにゃ")
                                .font(.headline)
                                .foregroundStyle(palette.primaryText)
                            Text(store.activeDeclineDraft?.tone ?? "カジュアル")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(palette.accent)
                        }
                    }

                    HStack {
                        Label("相手との関係", systemImage: "person.2.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(palette.primaryText)
                        Spacer()
                        Picker("相手との関係", selection: audienceBinding) {
                            ForEach(DeclineAudience.allCases) { audience in
                                Text(audience.title).tag(audience)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    .padding(.horizontal, MiraSpacing.sm)
                    .frame(minHeight: 48)
                    .background(palette.surface, in: RoundedRectangle(cornerRadius: MiraRadius.small))

                    TextEditor(text: draftTextBinding)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 170)
                        .padding(MiraSpacing.sm)
                        .background(palette.surface, in: RoundedRectangle(cornerRadius: MiraRadius.medium, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: MiraRadius.medium, style: .continuous)
                                .stroke(palette.primaryText.opacity(0.08), lineWidth: 1)
                        }
                        .accessibilityIdentifier("declineDraftEditor")

                    Button {
                        Task { await store.generateNextDeclineDraft() }
                    } label: {
                        Label("同じ相手向けに別案を作る", systemImage: "dice.fill")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(palette.surface, in: RoundedRectangle(cornerRadius: MiraRadius.medium))
                    }
                    .foregroundStyle(palette.accent)

                    PrimaryButton(title: "これをコピー", symbol: "doc.on.doc", palette: palette) {
                        UIPasteboard.general.string = store.activeDeclineDraft?.text
                        store.toast = "断り文をコピーしたにゃ"
                        dismiss()
                    }
                }
                .padding(MiraSpacing.lg)
            }
            .miraScreenBackground(palette)
            .navigationTitle(store.activeDeclineDraft?.title ?? "断り文")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        store.activeDeclineDraft = nil
                        dismiss()
                    }
                }
            }
        }
        .tint(palette.accent)
    }

    private var draftTextBinding: Binding<String> {
        Binding(
            get: { store.activeDeclineDraft?.text ?? "" },
            set: { newValue in
                guard var draft = store.activeDeclineDraft else { return }
                draft.text = newValue
                store.activeDeclineDraft = draft
            }
        )
    }

    private var audienceBinding: Binding<DeclineAudience> {
        Binding(
            get: { store.activeDeclineDraft?.audience ?? .friend },
            set: { audience in
                guard store.activeDeclineDraft?.audience != audience else { return }
                Task { await store.generateNextDeclineDraft(audience: audience) }
            }
        )
    }
}

struct ChangePreviewSheet: View {
    @Environment(MiraStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let palette: MiraThemePalette

    var body: some View {
        NavigationStack {
            Group {
                if let preview = store.pendingChangePreview {
                    ScrollView {
                        VStack(alignment: .leading, spacing: MiraSpacing.lg) {
                            HStack(spacing: MiraSpacing.md) {
                                PixelCatView(mood: preview.conflicts.isEmpty ? .thinking : .warning, size: 76)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("変更内容を確認してにゃ")
                                        .font(.title3.bold())
                                    Text("保存するまで実データは変わりません")
                                        .font(.caption)
                                        .foregroundStyle(palette.secondaryText)
                                }
                            }

                            VStack(alignment: .leading, spacing: MiraSpacing.md) {
                                changeRow(label: "変更前", item: preview.before, emphasized: false)
                                Image(systemName: "arrow.down")
                                    .foregroundStyle(palette.accent)
                                    .frame(maxWidth: .infinity)
                                changeRow(label: "変更後", item: preview.after, emphasized: true)
                            }
                            .miraCard(palette)

                            impactCard(conflicts: preview.conflicts, impact: preview.impact)

                            PrimaryButton(title: "変更を保存", symbol: "checkmark", palette: palette) {
                                store.applyChangePreview()
                                dismiss()
                            }
                        }
                        .padding(MiraSpacing.lg)
                    }
                    .miraScreenBackground(palette)
                } else {
                    ContentUnavailableView("変更案がありません", systemImage: "calendar.badge.exclamationmark")
                }
            }
            .navigationTitle("変更プレビュー")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        store.pendingChangePreview = nil
                        dismiss()
                    }
                }
            }
        }
        .tint(palette.accent)
    }

    private func changeRow(label: String, item: CalendarItemSnapshot, emphasized: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.caption.weight(.bold))
                .foregroundStyle(emphasized ? palette.accent : palette.secondaryText)
            Text(item.title)
                .font(.headline)
            Text("\(item.startDate.japaneseShortDate)  \(item.timeDescription)")
                .font(.subheadline)
                .foregroundStyle(palette.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func impactCard(conflicts: [String], impact: ScheduleImpact) -> some View {
        if conflicts.isEmpty && impact.overlappingMargins.isEmpty {
            Label("重複なし・余白への影響なし", systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.success)
                .miraCard(palette)
        } else {
            VStack(alignment: .leading, spacing: MiraSpacing.sm) {
                Label("変更後の影響", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundStyle(palette.warning)
                ForEach(conflicts, id: \.self) { conflict in
                    Text("・\(conflict)")
                        .font(.subheadline)
                }
                if !impact.overlappingMargins.isEmpty {
                    Text("・\(impact.message)")
                        .font(.subheadline)
                }
            }
            .foregroundStyle(palette.primaryText)
            .miraCard(palette)
        }
    }
}

struct EventCreationPreviewSheet: View {
    @Environment(MiraStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let palette: MiraThemePalette

    var body: some View {
        NavigationStack {
            Group {
                if let preview = store.pendingEventCreationPreview {
                    ScrollView {
                        VStack(alignment: .leading, spacing: MiraSpacing.lg) {
                            HStack(spacing: MiraSpacing.md) {
                                PixelCatView(mood: mood(for: preview), size: 78)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(headline(for: preview))
                                        .font(.title3.bold())
                                    Text("決めるのはあなた。影響と別案を先に見るにゃ。")
                                        .font(.caption)
                                        .foregroundStyle(palette.secondaryText)
                                }
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text(preview.event.title)
                                    .font(.headline)
                                Text("\(preview.event.startDate.japaneseShortDate)  \(preview.event.timeDescription)")
                                    .font(.subheadline)
                                    .foregroundStyle(palette.secondaryText)
                                Text("負荷：\(preview.event.loadClass.title) — \(preview.event.loadReason)")
                                    .font(.caption)
                                    .foregroundStyle(palette.secondaryText)
                            }
                            .miraCard(palette)

                            if !preview.conflicts.isEmpty || !preview.impact.overlappingMargins.isEmpty {
                                VStack(alignment: .leading, spacing: MiraSpacing.sm) {
                                    Text("気になる点")
                                        .font(.headline)
                                        .foregroundStyle(palette.warning)
                                    ForEach(preview.conflicts, id: \.self) { conflict in
                                        Text("・\(conflict)")
                                    }
                                    if !preview.impact.overlappingMargins.isEmpty {
                                        Text("・\(preview.impact.message)")
                                    }
                                    ForEach(sortedDeficitKinds(preview), id: \.self) { kind in
                                        Text("・\(kind.title) が目標より\(preview.impact.projectedGoalDeficits[kind, default: 0])枠不足")
                                    }
                                }
                                .font(.subheadline)
                                .foregroundStyle(palette.primaryText)
                                .miraCard(palette)
                            } else {
                                Label("この予定を入れても余白は守れそう", systemImage: "checkmark.circle.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(palette.success)
                                    .miraCard(palette)
                            }

                            if !preview.impact.relocationCandidates.isEmpty {
                                VStack(alignment: .leading, spacing: MiraSpacing.sm) {
                                    Text("余白を移すなら")
                                        .font(.headline)
                                    ForEach(preview.impact.relocationCandidates.prefix(3), id: \.self) { date in
                                        Label(date.japaneseShortDate, systemImage: "arrow.right.circle")
                                            .font(.subheadline)
                                    }
                                }
                                .foregroundStyle(palette.primaryText)
                                .miraCard(palette)

                                PrimaryButton(title: "余白を移して追加", symbol: "arrow.left.arrow.right", palette: palette) {
                                    store.applyEventCreationPreview(resolution: .relocate)
                                    dismiss()
                                }
                            }

                            PrimaryButton(
                                title: preview.conflicts.isEmpty && preview.impact.overlappingMargins.isEmpty ? "予定を追加" : "このまま追加する",
                                symbol: "calendar.badge.plus",
                                palette: palette
                            ) {
                                store.applyEventCreationPreview(resolution: .exception)
                                dismiss()
                            }
                        }
                        .padding(MiraSpacing.lg)
                    }
                    .miraScreenBackground(palette)
                } else {
                    ContentUnavailableView("追加案がありません", systemImage: "calendar.badge.exclamationmark")
                }
            }
            .navigationTitle("予定の確認")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        store.pendingEventCreationPreview = nil
                        dismiss()
                    }
                }
            }
        }
        .tint(palette.accent)
    }

    private func mood(for preview: EventCreationPreview) -> CatMood {
        preview.conflicts.isEmpty && preview.impact.overlappingMargins.isEmpty ? .relaxed : .warning
    }

    private func headline(for preview: EventCreationPreview) -> String {
        preview.conflicts.isEmpty && preview.impact.overlappingMargins.isEmpty
            ? "入れても大丈夫そうだにゃ"
            : "この時間、ちょっと気になるにゃ"
    }

    private func sortedDeficitKinds(_ preview: EventCreationPreview) -> [MarginKind] {
        preview.impact.projectedGoalDeficits.keys.sorted { $0.rawValue < $1.rawValue }
    }
}

struct RebalanceProposalSheet: View {
    @Environment(MiraStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let palette: MiraThemePalette

    var body: some View {
        NavigationStack {
            Group {
                if let proposal = store.activeRebalanceProposal {
                    ScrollView {
                        VStack(alignment: .leading, spacing: MiraSpacing.lg) {
                            HStack(spacing: MiraSpacing.md) {
                                PixelCatView(mood: .thinking, size: 84)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("完成案を持ってきたにゃ")
                                        .font(.title3.bold())
                                    Text(proposal.summary)
                                        .font(.subheadline)
                                        .foregroundStyle(palette.secondaryText)
                                }
                            }

                            ForEach(proposal.moves) { move in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(move.title)
                                        .font(.headline)
                                    if isExistingMargin(move) {
                                        HStack {
                                            Text(move.from.japaneseShortDate)
                                                .strikethrough()
                                            Image(systemName: "arrow.right")
                                                .foregroundStyle(palette.accent)
                                            Text(move.to.japaneseShortDate)
                                                .fontWeight(.semibold)
                                        }
                                        .font(.subheadline)
                                    } else {
                                        Label("\(move.to.japaneseShortDate) に新しく追加", systemImage: "plus.circle.fill")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(palette.accent)
                                    }
                                    Text(move.benefit)
                                        .font(.caption)
                                        .foregroundStyle(palette.secondaryText)
                                }
                                .miraCard(palette)
                            }

                            PrimaryButton(title: "この案を適用", symbol: "sparkles", palette: palette) {
                                store.applyRebalanceProposal(proposal)
                                dismiss()
                            }

                            Button("今回は見送る") {
                                store.dismissRebalanceProposal(proposal)
                                dismiss()
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(palette.secondaryText)
                            .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .padding(MiraSpacing.lg)
                    }
                    .miraScreenBackground(palette)
                } else {
                    ContentUnavailableView("再設計案はありません", systemImage: "leaf")
                }
            }
            .navigationTitle("余白の再設計")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .tint(palette.accent)
    }

    private func isExistingMargin(_ move: RebalanceMove) -> Bool {
        store.items.contains { $0.id == move.marginItemID && $0.kind == .margin }
    }
}
