import SwiftUI

struct MiraAssistantView: View {
    @Environment(MiraStore.self) private var store
    let palette: MiraThemePalette

    @State private var request = ""
    @State private var choices: [PlanningIntent] = []
    @State private var notice: String?
    @State private var showShare = false
    @FocusState private var isRequestFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MiraSpacing.lg) {
                requestCard
                suggestionsSection
                reviewCard
                shareCard
                historySection
            }
            .padding(.horizontal, MiraSpacing.md)
            .padding(.top, MiraSpacing.sm)
            .padding(.bottom, 104)
        }
        .background(palette.background)
        .navigationTitle("Mira")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShare) {
            AvailabilityShareSheet(palette: palette)
        }
        .task {
            await store.refreshProactiveSuggestions()
        }
    }

    // MARK: Request

    private var requestCard: some View {
        VStack(alignment: .leading, spacing: MiraSpacing.sm) {
            Text("どんな時間にしたい？")
                .font(.headline)
                .foregroundStyle(palette.primaryText)
            HStack(spacing: MiraSpacing.xs) {
                TextField("例：来週は自分の時間を増やしたい", text: $request)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, MiraSpacing.sm)
                    .frame(minHeight: 44)
                    .background(palette.background, in: RoundedRectangle(cornerRadius: MiraRadius.small, style: .continuous))
                    .focused($isRequestFocused)
                    .submitLabel(.send)
                    .onSubmit(send)
                    .accessibilityIdentifier("mira.request")
                Button(action: send) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(request.isEmpty ? palette.secondaryText.opacity(0.4) : palette.accent)
                        .frame(width: 44, height: 44)
                }
                .disabled(request.isEmpty)
                .accessibilityLabel("送信")
            }

            if let notice {
                Text(notice)
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)
            }

            if !choices.isEmpty {
                VStack(alignment: .leading, spacing: MiraSpacing.xs) {
                    ForEach(choices, id: \.self) { intent in
                        Button(intent.label) { choose(intent) }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(palette.accent)
                            .padding(.horizontal, MiraSpacing.sm)
                            .frame(minHeight: 40)
                            .background(palette.accentSoft, in: Capsule())
                    }
                }
            }

            Text("Miraは提案だけします。置くかどうかは、あなたが決めます。")
                .font(.caption)
                .foregroundStyle(palette.secondaryText)
        }
        .miraCard(palette)
    }

    private func send() {
        let text = request.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isRequestFocused = false
        handle(store.submitRequest(text))
    }

    private func choose(_ intent: PlanningIntent) {
        handle(store.submitIntent(intent))
    }

    private func handle(_ outcome: MiraStore.RequestOutcome) {
        withAnimation(MiraMotion.standard) {
            switch outcome {
            case .suggested:
                request = ""
                choices = []
                notice = nil
            case .needsChoice(let options):
                choices = options
                notice = "こういうことかな？近いものを選んでね。"
            case .nothingFits:
                choices = []
                notice = "その週には、予定とぶつからずに置ける時間が見つかりませんでした。"
            }
        }
    }

    // MARK: Suggestions

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: MiraSpacing.sm) {
            Text("Miraからの提案")
                .font(.title3.bold())
                .foregroundStyle(palette.primaryText)
            if store.visibleSuggestions.isEmpty {
                Text("今は提案はありません。気になることがあれば、上に書いてね。")
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .miraCard(palette)
            } else {
                ForEach(store.visibleSuggestions) { suggestion in
                    SuggestionCard(
                        suggestion: suggestion,
                        palette: palette,
                        apply: { withAnimation(MiraMotion.standard) { store.applySuggestion(id: suggestion.id) } },
                        dismiss: { withAnimation(MiraMotion.standard) { store.dismissSuggestion(id: suggestion.id) } }
                    )
                }
            }
        }
    }

    // MARK: Review

    private var reviewCard: some View {
        let summary = store.weeklyReview(for: store.currentWeek)
        return VStack(alignment: .leading, spacing: MiraSpacing.sm) {
            Text("今週のふりかえり")
                .font(.title3.bold())
                .foregroundStyle(palette.primaryText)
            HStack(alignment: .firstTextBaseline) {
                Text("自分の時間")
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)
                Spacer()
                Text("\(Int(summary.selfTimeHours.rounded()))時間 / 目安\(Int(summary.targetHours))時間")
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundStyle(palette.primaryText)
            }
            .accessibilityElement(children: .combine)
            ProgressView(value: summary.ratio)
                .tint(palette.accent)
            Text("採用した提案 \(summary.appliedSuggestions)件・見送り \(summary.dismissedSuggestions)件")
                .font(.caption)
                .foregroundStyle(palette.secondaryText)

            Text("今週はどうだった？")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.primaryText)
                .padding(.top, MiraSpacing.xxs)
            HStack(spacing: MiraSpacing.xs) {
                ForEach(Satisfaction.allCases) { value in
                    let isSelected = summary.satisfaction == value
                    Button {
                        store.setSatisfaction(value, for: store.currentWeek)
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: value.symbolName)
                                .accessibilityHidden(true)
                            Text(value.title)
                                .font(.caption.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .foregroundStyle(isSelected ? Color.white : palette.primaryText)
                        .background(
                            isSelected ? palette.accent : palette.accentSoft,
                            in: RoundedRectangle(cornerRadius: MiraRadius.small, style: .continuous)
                        )
                    }
                    .buttonStyle(MiraPressStyle())
                    .accessibilityLabel(value.title)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            if summary.satisfaction == .low {
                Text("来週は自分の時間を少し多めに提案するね。")
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
            }
        }
        .miraCard(palette)
    }

    // MARK: Share

    private var shareCard: some View {
        Button { showShare = true } label: {
            HStack(spacing: MiraSpacing.sm) {
                Image(systemName: "person.2.wave.2.fill")
                    .font(.title3)
                    .foregroundStyle(palette.accent)
                    .frame(width: 36)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("空き枠を共有")
                        .font(.headline)
                        .foregroundStyle(palette.primaryText)
                    Text("予定の中身は見せずに、空いている時間だけ伝えます")
                        .font(.caption)
                        .foregroundStyle(palette.secondaryText)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .foregroundStyle(palette.secondaryText)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .miraCard(palette)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("空き枠を共有")
    }

    // MARK: History

    @ViewBuilder
    private var historySection: some View {
        if !store.suggestionHistory.isEmpty {
            VStack(alignment: .leading, spacing: MiraSpacing.sm) {
                Text("最近の提案")
                    .font(.title3.bold())
                    .foregroundStyle(palette.primaryText)
                VStack(spacing: 0) {
                    ForEach(store.suggestionHistory) { suggestion in
                        HStack(spacing: MiraSpacing.sm) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(suggestion.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(palette.primaryText)
                                Text(statusLabel(suggestion.status))
                                    .font(.caption)
                                    .foregroundStyle(palette.secondaryText)
                            }
                            Spacer(minLength: 0)
                            if suggestion.status == .applied {
                                Button("取り消す") {
                                    withAnimation(MiraMotion.standard) { store.undoSuggestion(id: suggestion.id) }
                                }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(palette.accent)
                                .frame(minHeight: 44)
                            }
                        }
                        .padding(.vertical, MiraSpacing.xs)
                    }
                }
                .miraCard(palette)
            }
        }
    }

    private func statusLabel(_ status: SuggestionStatus) -> String {
        switch status {
        case .pending: "提案中"
        case .applied: "置きました"
        case .dismissed: "見送りました"
        case .undone: "取り消しました"
        }
    }
}

struct SuggestionCard: View {
    let suggestion: Suggestion
    let palette: MiraThemePalette
    let apply: () -> Void
    let dismiss: () -> Void

    private let labels = AvailabilityShareEngine()

    var body: some View {
        VStack(alignment: .leading, spacing: MiraSpacing.sm) {
            HStack(spacing: MiraSpacing.xs) {
                Image(systemName: suggestion.origin == .proactive ? "bell.badge.fill" : "sparkles")
                    .foregroundStyle(palette.accent)
                    .accessibilityHidden(true)
                Text(suggestion.title)
                    .font(.headline)
                    .foregroundStyle(palette.primaryText)
            }
            if suggestion.usesTrend {
                Label("最近の傾向から", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.accent)
                    .padding(.horizontal, MiraSpacing.xs)
                    .padding(.vertical, 4)
                    .background(palette.accentSoft, in: Capsule())
            }
            Text(suggestion.reason)
                .font(.subheadline)
                .foregroundStyle(palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: MiraSpacing.xs) {
                ForEach(suggestion.margins) { margin in
                    HStack(spacing: MiraSpacing.xs) {
                        Image(systemName: margin.kind.symbolName)
                            .foregroundStyle(palette.rest)
                            .frame(width: 22)
                            .accessibilityHidden(true)
                        Text("\(labels.dayLabel(margin.startDate)) \(labels.timeLabel(margin.startDate))〜\(labels.timeLabel(margin.endDate))")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(palette.primaryText)
                        Spacer(minLength: 0)
                        Text(margin.kind.title)
                            .font(.caption)
                            .foregroundStyle(palette.secondaryText)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(MiraSpacing.sm)
            .background(palette.background, in: RoundedRectangle(cornerRadius: MiraRadius.small, style: .continuous))

            PrimaryButton(title: "この案で置く", symbol: "checkmark", palette: palette, action: apply)
            Button("今回は見送る", action: dismiss)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.secondaryText)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .miraCard(palette)
    }
}
