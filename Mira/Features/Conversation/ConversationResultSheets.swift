import SwiftUI
import UIKit

struct ConversationClarificationSheet: View {
    @Environment(MiraStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let palette: MiraThemePalette
    let clarification: ConversationClarification

    var body: some View {
        NavigationStack {
            VStack(spacing: MiraSpacing.lg) {
                PixelCatView(mood: .thinking, size: 96)

                VStack(spacing: MiraSpacing.xs) {
                    Text(clarification.question)
                        .font(.title2.bold())
                        .foregroundStyle(palette.primaryText)
                        .multilineTextAlignment(.center)
                    Text("必要なことだけ聞くにゃ")
                        .font(.subheadline)
                        .foregroundStyle(palette.secondaryText)
                }

                VStack(spacing: MiraSpacing.sm) {
                    ForEach(clarification.options, id: \.self) { option in
                        Button {
                            dismiss()
                            Task { await store.answerClarification(option) }
                        } label: {
                            HStack {
                                Text(option)
                                    .font(.headline)
                                Spacer()
                                Image(systemName: "arrow.right")
                            }
                            .foregroundStyle(palette.primaryText)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .padding(.horizontal, MiraSpacing.md)
                            .background(palette.surface, in: RoundedRectangle(cornerRadius: MiraRadius.medium, style: .continuous))
                        }
                        .buttonStyle(MiraPressStyle())
                    }
                }

                Spacer()
            }
            .padding(MiraSpacing.lg)
            .background(palette.background)
            .navigationTitle("Miraに確認")
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
        .tint(palette.accent)
        .presentationDetents([.medium, .large])
    }
}

struct DeclineDraftSheet: View {
    @Environment(MiraStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let palette: MiraThemePalette
    let draft: DeclineDraft

    @State private var editableText = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: MiraSpacing.lg) {
                    HStack(spacing: MiraSpacing.md) {
                        PixelCatView(mood: .thinking, size: 74)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("嘘をつかずに断る文を作ったにゃ")
                                .font(.headline)
                                .foregroundStyle(palette.primaryText)
                            Text("何度でも言い換えられます")
                                .font(.caption)
                                .foregroundStyle(palette.secondaryText)
                        }
                        Spacer()
                    }
                    .miraCard(palette)

                    VStack(alignment: .leading, spacing: MiraSpacing.sm) {
                        HStack {
                            Text(draft.title)
                                .font(.headline)
                                .foregroundStyle(palette.primaryText)
                            Spacer()
                            Text(draft.tone)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(palette.accent)
                                .padding(.horizontal, 9)
                                .frame(minHeight: 28)
                                .background(palette.accentSoft, in: Capsule())
                        }

                        TextEditor(text: $editableText)
                            .font(.body)
                            .foregroundStyle(palette.primaryText)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 150)
                            .padding(MiraSpacing.sm)
                            .background(palette.elevatedBackground, in: RoundedRectangle(cornerRadius: MiraRadius.medium, style: .continuous))
                    }
                    .miraCard(palette)

                    HStack(spacing: MiraSpacing.sm) {
                        Button {
                            Task { await store.generateNextDeclineDraft() }
                        } label: {
                            Label("もう一個", systemImage: "dice.fill")
                                .frame(maxWidth: .infinity, minHeight: 48)
                        }
                        .foregroundStyle(palette.primaryText)
                        .background(palette.surface, in: RoundedRectangle(cornerRadius: MiraRadius.medium, style: .continuous))
                        .buttonStyle(MiraPressStyle())

                        Button {
                            Task { await store.generateNextDeclineDraft(softer: true) }
                        } label: {
                            Label("柔らかく", systemImage: "heart.fill")
                                .frame(maxWidth: .infinity, minHeight: 48)
                        }
                        .foregroundStyle(palette.primaryText)
                        .background(palette.surface, in: RoundedRectangle(cornerRadius: MiraRadius.medium, style: .continuous))
                        .buttonStyle(MiraPressStyle())
                    }

                    PrimaryButton(title: "これをコピー", symbol: "doc.on.doc", palette: palette) {
                        UIPasteboard.general.string = editableText
                        store.toast = "断り文をコピーしたにゃ"
                        store.activeDeclineDraft = nil
                        dismiss()
                    }
                }
                .padding(MiraSpacing.md)
            }
            .background(palette.background)
            .navigationTitle("断り文")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        store.activeDeclineDraft = nil
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: editableText) {
                        Image(systemName: "square.and.arrow.up")
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("断り文を共有")
                }
            }
            .onAppear { editableText = draft.text }
            .onChange(of: store.activeDeclineDraft?.text) { _, newValue in
                if let newValue { editableText = newValue }
            }
        }
        .tint(palette.accent)
    }
}

struct ChangePreviewSheet: View {
    @Environment(MiraStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let palette: MiraThemePalette
    let preview: ChangePreview

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: MiraSpacing.lg) {
                    HStack(spacing: MiraSpacing.md) {
                        PixelCatView(mood: preview.conflicts.isEmpty ? .thinking : .warning, size: 76)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("変更内容を確認してにゃ")
                                .font(.headline)
                            Text("AIは変更案まで。保存はあなたが決めます。")
                                .font(.caption)
                                .foregroundStyle(palette.secondaryText)
                        }
                        Spacer()
                    }
                    .miraCard(palette)

                    VStack(alignment: .leading, spacing: MiraSpacing.md) {
                        Text(preview.title)
                            .font(.title3.bold())

                        diffRow(
                            label: "変更前",
                            date: preview.before.startDate,
                            time: preview.before.timeDescription,
                            emphasis: false
                        )

                        HStack {
                            Spacer()
                            Image(systemName: "arrow.down")
                                .foregroundStyle(palette.accent)
                            Spacer()
                        }

                        diffRow(
                            label: "変更後",
                            date: preview.after.startDate,
                            time: preview.after.timeDescription,
                            emphasis: true
                        )
                    }
                    .foregroundStyle(palette.primaryText)
                    .miraCard(palette)

                    impactCard

                    PrimaryButton(title: "変更を保存", symbol: "checkmark", palette: palette) {
                        store.applyChangePreview()
                        dismiss()
                    }

                    Button("詳しく編集する") {
                        store.toast = "詳細編集は予定画面から開けるにゃ"
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.accent)
                    .frame(minHeight: 44)
                }
                .padding(MiraSpacing.md)
            }
            .background(palette.background)
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

    private var impactCard: some View {
        VStack(alignment: .leading, spacing: MiraSpacing.sm) {
            Label(
                preview.conflicts.isEmpty && preview.impact.projectedGoalDeficits.isEmpty ? "余白への大きな影響なし" : "変更後の影響",
                systemImage: preview.conflicts.isEmpty ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
            )
            .font(.headline)
            .foregroundStyle(preview.conflicts.isEmpty ? palette.accent : palette.warning)

            ForEach(preview.conflicts, id: \.self) { conflict in
                Text("・\(conflict)")
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)
            }

            ForEach(sortedDeficits, id: \.0) { kind, deficit in
                Text("・\(kind.title)があと\(deficit)枠必要")
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .miraCard(palette)
    }

    private var sortedDeficits: [(MarginKind, Int)] {
        preview.impact.projectedGoalDeficits.sorted { $0.key.defaultPriority > $1.key.defaultPriority }
    }

    private func diffRow(label: String, date: Date, time: String, emphasis: Bool) -> some View {
        HStack(spacing: MiraSpacing.sm) {
            Text(label)
                .font(.caption.weight(.bold))
                .foregroundStyle(emphasis ? palette.accent : palette.secondaryText)
                .frame(width: 58, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(date.japaneseDayTitle)
                    .font(.headline)
                Text(time)
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)
            }
            Spacer()
        }
        .padding(MiraSpacing.sm)
        .background(emphasis ? palette.accentSoft : palette.elevatedBackground, in: RoundedRectangle(cornerRadius: MiraRadius.small, style: .continuous))
    }
}

struct EventCreationPreviewSheet: View {
    @Environment(MiraStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let palette: MiraThemePalette
    let preview: EventCreationPreview

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: MiraSpacing.lg) {
                    HStack(spacing: MiraSpacing.md) {
                        PixelCatView(mood: hasImpact ? .warning : .happy, size: 78)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(hasImpact ? "この時間、ちょっと気になるにゃ" : "ここなら余白も守れそうだにゃ")
                                .font(.headline)
                            Text(hasImpact ? "影響と別案を見てから決められます" : "内容を確認して追加できます")
                                .font(.caption)
                                .foregroundStyle(palette.secondaryText)
                        }
                        Spacer()
                    }
                    .miraCard(palette)

                    VStack(alignment: .leading, spacing: MiraSpacing.sm) {
                        Text(preview.event.title)
                            .font(.title3.bold())
                        Label(preview.event.startDate.japaneseDayTitle, systemImage: "calendar")
                        Label(preview.event.timeDescription, systemImage: "clock")
                        Label("負荷：\(preview.event.loadClass.title)", systemImage: "gauge.with.dots.needle.33percent")
                    }
                    .font(.subheadline)
                    .foregroundStyle(palette.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .miraCard(palette)

                    if hasImpact {
                        VStack(alignment: .leading, spacing: MiraSpacing.sm) {
                            Text("入れた場合")
                                .font(.headline)
                            ForEach(preview.conflicts, id: \.self) { conflict in
                                Label(conflict, systemImage: "exclamationmark.triangle.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(palette.warning)
                            }
                            ForEach(sortedDeficits, id: \.0) { kind, deficit in
                                HStack {
                                    Image(systemName: kind.symbolName)
                                        .foregroundStyle(palette.warning)
                                    Text("\(kind.title)があと\(deficit)枠不足")
                                    Spacer()
                                }
                                .font(.subheadline)
                            }
                            if !preview.impact.message.isEmpty {
                                Text(preview.impact.message)
                                    .font(.subheadline)
                                    .foregroundStyle(palette.secondaryText)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .miraCard(palette)
                    }

                    if !preview.impact.relocationCandidates.isEmpty {
                        PrimaryButton(title: "余白を別日に移して追加", symbol: "arrow.left.arrow.right", palette: palette) {
                            store.applyEventCreationPreview(
                                resolution: .relocate,
                                relocationDate: preview.impact.relocationCandidates.first
                            )
                            dismiss()
                        }
                    }

                    Button {
                        store.beginAlternativeScheduling(for: preview)
                        dismiss()
                    } label: {
                        Label("別候補を見る", systemImage: "calendar.badge.clock")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .foregroundStyle(palette.primaryText)
                            .background(palette.surface, in: RoundedRectangle(cornerRadius: MiraRadius.medium, style: .continuous))
                    }
                    .buttonStyle(MiraPressStyle())

                    Button {
                        store.applyEventCreationPreview(resolution: .exception)
                        dismiss()
                    } label: {
                        Text(hasImpact ? "このまま追加する" : "予定を追加")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .foregroundStyle(hasImpact ? palette.warning : Color.white)
                            .background(hasImpact ? palette.warning.opacity(0.12) : palette.accent, in: RoundedRectangle(cornerRadius: MiraRadius.medium, style: .continuous))
                    }
                    .buttonStyle(MiraPressStyle())
                }
                .padding(MiraSpacing.md)
            }
            .background(palette.background)
            .navigationTitle("予定を確認")
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

    private var hasImpact: Bool {
        !preview.conflicts.isEmpty || !preview.impact.projectedGoalDeficits.isEmpty || !preview.impact.overlappingMargins.isEmpty
    }

    private var sortedDeficits: [(MarginKind, Int)] {
        preview.impact.projectedGoalDeficits.sorted { $0.key.defaultPriority > $1.key.defaultPriority }
    }
}

struct RebalanceProposalSheet: View {
    @Environment(MiraStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let palette: MiraThemePalette
    let proposal: RebalanceProposal

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: MiraSpacing.lg) {
                    HStack(spacing: MiraSpacing.md) {
                        PixelCatView(mood: .thinking, size: 78)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("完成案を作っておいたにゃ")
                                .font(.headline)
                            Text("計算は自動。変更はまだしていません。")
                                .font(.caption)
                                .foregroundStyle(palette.secondaryText)
                        }
                        Spacer()
                    }
                    .miraCard(palette)

                    Text(proposal.summary)
                        .font(.body)
                        .foregroundStyle(palette.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(proposal.moves) { move in
                        VStack(alignment: .leading, spacing: MiraSpacing.sm) {
                            HStack {
                                Image(systemName: "leaf.fill")
                                    .foregroundStyle(palette.accent)
                                Text(move.title)
                                    .font(.headline)
                                Spacer()
                            }

                            if move.from != MonthKey(date: proposal.month).firstDay {
                                HStack {
                                    Text(move.from.japaneseShortDate)
                                        .foregroundStyle(palette.secondaryText)
                                    Image(systemName: "arrow.right")
                                        .foregroundStyle(palette.accent)
                                    Text(move.to.japaneseShortDate)
                                        .fontWeight(.semibold)
                                }
                                .font(.subheadline)
                            } else {
                                Text("\(move.to.japaneseShortDate)へ追加")
                                    .font(.subheadline.weight(.semibold))
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

                    Button("今回はしない") {
                        store.dismissRebalanceProposal(proposal)
                        dismiss()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.secondaryText)
                    .frame(minHeight: 44)
                }
                .padding(MiraSpacing.md)
            }
            .background(palette.background)
            .navigationTitle("余白の組み直し")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .tint(palette.accent)
    }
}

struct MarginComfortSheet: View {
    @Environment(MiraStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let palette: MiraThemePalette

    @State private var selection: MarginComfortLevel = .standard

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: MiraSpacing.lg) {
                    HStack(spacing: MiraSpacing.md) {
                        PixelCatView(mood: .relaxed, size: 78)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("休む量もMiraに任せられるにゃ")
                                .font(.headline)
                            Text("今月の予定負荷から必要量を計算します")
                                .font(.caption)
                                .foregroundStyle(palette.secondaryText)
                        }
                        Spacer()
                    }
                    .miraCard(palette)

                    ForEach(MarginComfortLevel.allCases) { level in
                        Button {
                            selection = level
                        } label: {
                            HStack(spacing: MiraSpacing.md) {
                                Image(systemName: selection == level ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selection == level ? palette.accent : palette.secondaryText)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(level.title)
                                        .font(.headline)
                                    Text(level.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(palette.secondaryText)
                                }
                                Spacer()
                            }
                            .foregroundStyle(palette.primaryText)
                            .miraCard(palette)
                            .overlay {
                                RoundedRectangle(cornerRadius: MiraRadius.medium, style: .continuous)
                                    .stroke(selection == level ? palette.accent : Color.clear, lineWidth: 2)
                            }
                        }
                        .buttonStyle(MiraPressStyle())
                    }

                    if let recommendation = previewRecommendation {
                        VStack(alignment: .leading, spacing: MiraSpacing.sm) {
                            Text("この月のおすすめ")
                                .font(.headline)
                            ForEach(recommendation.targets.sorted(by: { $0.key.defaultPriority > $1.key.defaultPriority }), id: \.key) { kind, count in
                                HStack {
                                    Image(systemName: kind.symbolName)
                                        .foregroundStyle(palette.accent)
                                    Text(kind.title)
                                    Spacer()
                                    Text("\(count)回")
                                        .font(.subheadline.monospacedDigit().weight(.semibold))
                                }
                            }
                        }
                        .miraCard(palette)
                    }

                    PrimaryButton(title: "この量で組み直す", symbol: "sparkles", palette: palette) {
                        store.setMarginComfortLevel(selection, applyRecommendation: true)
                        dismiss()
                    }
                }
                .padding(MiraSpacing.md)
            }
            .background(palette.background)
            .navigationTitle("余白の多さ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .onAppear { selection = store.marginComfortLevel }
        }
        .tint(palette.accent)
    }

    private var previewRecommendation: MarginRecommendation? {
        store.marginRecommendationEngine.recommend(
            month: store.selectedMonth,
            items: store.items,
            comfort: selection
        )
    }
}
