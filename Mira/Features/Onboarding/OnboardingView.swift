import SwiftUI

private enum OnboardingMarginMode: String, CaseIterable, Identifiable {
    case automatic
    case manual

    var id: String { rawValue }
}

struct OnboardingView: View {
    @Environment(MiraStore.self) private var store
    let palette: MiraThemePalette

    @State private var step = 0
    @State private var selections: Set<MarginKind> = [.rest, .freeEvening, .reading, .solo, .importantPeople]
    @State private var targets: [MarginKind: Int] = [
        .rest: 4,
        .freeEvening: 8,
        .reading: 2,
        .solo: 2,
        .personalProject: 2,
        .importantPeople: 2
    ]
    @State private var marginMode: OnboardingMarginMode = .automatic
    @State private var marginComfort: MarginComfortLevel = .standard
    @State private var freeEveningsPerWeek = 2
    @State private var availabilityRules = AvailabilityRuleDraft.standardWeekdays

    private let totalSteps = 6

    var body: some View {
        VStack(spacing: 0) {
            progressHeader
                .padding(.horizontal, MiraSpacing.lg)
                .padding(.top, MiraSpacing.md)

            TabView(selection: $step) {
                welcome.tag(0)
                chooseMargins.tag(1)
                chooseAmounts.tag(2)
                freeEvenings.tag(3)
                basicUnavailableTimes.tag(4)
                ready.tag(5)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(MiraMotion.standard, value: step)

            navigationButtons
                .padding(.horizontal, MiraSpacing.lg)
                .padding(.bottom, MiraSpacing.lg)
        }
        .foregroundStyle(palette.primaryText)
        .accessibilityElement(children: .contain)
    }

    private var recommendation: MarginRecommendation {
        store.marginRecommendationEngine.recommend(
            month: store.selectedMonth,
            items: store.items,
            comfort: marginComfort
        )
    }

    private var progressHeader: some View {
        HStack(spacing: MiraSpacing.xs) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Capsule()
                    .fill(index <= step ? palette.accent : palette.secondaryText.opacity(0.18))
                    .frame(height: 5)
            }
        }
        .accessibilityLabel("初期設定 \(step + 1) / \(totalSteps)")
    }

    private var welcome: some View {
        VStack(spacing: MiraSpacing.lg) {
            Spacer()
            PixelCatView(mood: .relaxed, size: 132)
            VStack(spacing: MiraSpacing.sm) {
                Text("空いている時間を埋める前に")
                    .font(.title3.weight(.semibold))
                Text("自分のための時間を守ろう。")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
            }
            Text("余白は、予定が入らなかった残りものではありません。\n先に置いて、大切にできる時間です。")
                .font(.body)
                .foregroundStyle(palette.secondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
            Spacer()
        }
        .padding(MiraSpacing.lg)
    }

    private var chooseMargins: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MiraSpacing.lg) {
                onboardingTitle("今月、どんな時間がほしい？", subtitle: "いくつでも選べます。あとから変更できます。")

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: MiraSpacing.sm) {
                    ForEach([MarginKind.rest, .reading, .solo, .personalProject, .importantPeople, .freeEvening]) { kind in
                        Button {
                            if selections.contains(kind) { selections.remove(kind) } else { selections.insert(kind) }
                        } label: {
                            VStack(alignment: .leading, spacing: MiraSpacing.sm) {
                                Image(systemName: kind.symbolName)
                                    .font(.title2)
                                    .accessibilityHidden(true)
                                Text(kind.title)
                                    .font(.headline)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                                Image(systemName: selections.contains(kind) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selections.contains(kind) ? palette.accent : palette.secondaryText)
                                    .accessibilityHidden(true)
                            }
                            .frame(maxWidth: .infinity, minHeight: 128, alignment: .leading)
                            .foregroundStyle(palette.primaryText)
                            .miraCard(palette)
                            .overlay {
                                RoundedRectangle(cornerRadius: MiraRadius.medium, style: .continuous)
                                    .stroke(selections.contains(kind) ? palette.accent : .clear, lineWidth: 2)
                            }
                        }
                        .buttonStyle(MiraPressStyle())
                        .accessibilityLabel(kind.title)
                        .accessibilityValue(selections.contains(kind) ? "選択済み" : "未選択")
                    }
                }
            }
            .padding(MiraSpacing.lg)
        }
    }

    private var chooseAmounts: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MiraSpacing.lg) {
                onboardingTitle("余白の量、どうする？", subtitle: "考えるのが大変なら、今ある予定の負荷からMiraが決めます。")

                Picker("余白の決め方", selection: $marginMode) {
                    Text("Miraにおまかせ").tag(OnboardingMarginMode.automatic)
                    Text("自分で決める").tag(OnboardingMarginMode.manual)
                }
                .pickerStyle(.segmented)

                if marginMode == .automatic {
                    VStack(alignment: .leading, spacing: MiraSpacing.sm) {
                        Text("余白の多さ")
                            .font(.headline)
                        ForEach(MarginComfortLevel.allCases) { level in
                            Button {
                                marginComfort = level
                            } label: {
                                HStack(spacing: MiraSpacing.sm) {
                                    Image(systemName: marginComfort == level ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(marginComfort == level ? palette.accent : palette.secondaryText)
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
                                .miraCard(palette, padding: MiraSpacing.sm)
                            }
                            .buttonStyle(MiraPressStyle())
                        }
                    }

                    VStack(alignment: .leading, spacing: MiraSpacing.sm) {
                        HStack {
                            Label("今月のおすすめ", systemImage: "sparkles")
                                .font(.headline)
                                .foregroundStyle(palette.accent)
                            Spacer()
                            Text(marginComfort.title)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(palette.secondaryText)
                        }
                        ForEach(selections.sorted(by: { $0.defaultPriority > $1.defaultPriority })) { kind in
                            HStack {
                                Image(systemName: kind.symbolName)
                                    .foregroundStyle(palette.accent)
                                    .frame(width: 24)
                                Text(kind.title)
                                    .font(.subheadline)
                                Spacer()
                                Text("\(recommendation.targets[kind, default: targets[kind, default: 0]])回")
                                    .font(.subheadline.monospacedDigit().weight(.semibold))
                            }
                        }
                        Divider().overlay(palette.primaryText.opacity(0.08))
                        ForEach(recommendation.reasons, id: \.self) { reason in
                            Text("・\(reason)")
                                .font(.caption)
                                .foregroundStyle(palette.secondaryText)
                        }
                    }
                    .miraCard(palette)
                } else {
                    ForEach(selections.sorted(by: { $0.defaultPriority > $1.defaultPriority })) { kind in
                        HStack(spacing: MiraSpacing.md) {
                            Image(systemName: kind.symbolName)
                                .frame(width: 30)
                                .foregroundStyle(palette.accent)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(kind.title).font(.headline)
                                Text(kind == .rest ? "終日を大きく確保" : "前後の余裕を含む大きめ枠")
                                    .font(.caption)
                                    .foregroundStyle(palette.secondaryText)
                            }
                            Spacer()
                            Stepper("", value: binding(for: kind), in: 0...12)
                                .labelsHidden()
                            Text("\(targets[kind, default: 0])回")
                                .font(.headline.monospacedDigit())
                                .frame(width: 44, alignment: .trailing)
                        }
                        .miraCard(palette)
                    }
                }
            }
            .padding(MiraSpacing.lg)
        }
    }

    private var freeEvenings: some View {
        VStack(spacing: MiraSpacing.xl) {
            Spacer()
            PixelCatView(mood: .sleeping, size: 112)
            onboardingTitle("予定のない夜は、週に何日ほしい？", subtitle: marginMode == .automatic ? "Miraのおすすめを基準に、ここだけ好みを上書きできます。" : "仕事だけの日は、予定のない夜として数えます。")
                .multilineTextAlignment(.center)

            HStack(spacing: MiraSpacing.sm) {
                ForEach(0...3, id: \.self) { count in
                    Button {
                        freeEveningsPerWeek = count
                        targets[.freeEvening] = count * 4
                        if count > 0 { selections.insert(.freeEvening) }
                    } label: {
                        VStack(spacing: 4) {
                            Text(count == 3 ? "3+" : "\(count)")
                                .font(.title2.bold().monospacedDigit())
                            Text("日")
                                .font(.caption)
                        }
                        .frame(width: 68, height: 72)
                        .foregroundStyle(freeEveningsPerWeek == count ? .white : palette.primaryText)
                        .background(freeEveningsPerWeek == count ? palette.accent : palette.surface)
                        .clipShape(RoundedRectangle(cornerRadius: MiraRadius.medium, style: .continuous))
                    }
                    .buttonStyle(MiraPressStyle())
                    .accessibilityLabel("週に\(count)日")
                }
            }
            Spacer()
        }
        .padding(MiraSpacing.lg)
    }

    private var basicUnavailableTimes: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MiraSpacing.lg) {
                onboardingTitle(
                    "普段、予定を入れたくない時間はある？",
                    subtitle: "仕事や学校などを曜日ごとに設定します。余白や日程候補はこの時間を避けます。"
                )

                HStack(spacing: MiraSpacing.sm) {
                    Image(systemName: "clock.fill")
                        .font(.title2)
                        .foregroundStyle(palette.accent)
                        .frame(width: 48, height: 48)
                        .background(palette.accentSoft, in: RoundedRectangle(cornerRadius: MiraRadius.small))
                        .accessibilityHidden(true)
                    Text("平日はまとめて設定して、違う曜日だけ時刻を変えられます。設定なしでも始められます。")
                        .font(.subheadline)
                        .foregroundStyle(palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .miraCard(palette, padding: MiraSpacing.sm)

                AvailabilityRuleEditor(rules: $availabilityRules, palette: palette)
            }
            .padding(MiraSpacing.lg)
            .padding(.bottom, MiraSpacing.md)
        }
    }

    private var ready: some View {
        ScrollView {
            VStack(spacing: MiraSpacing.lg) {
                Spacer(minLength: MiraSpacing.lg)
                PixelCatView(mood: .celebrating, size: 124)
                onboardingTitle("あなたの余白を置いてみるにゃ", subtitle: "今ある予定と基本時間を避けて、休む日や自分の時間をおすすめ配置します。")
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: MiraSpacing.sm) {
                    HStack {
                        Text("余白量")
                        Spacer()
                        Text(marginMode == .automatic ? "Miraにおまかせ・\(marginComfort.title)" : "自分で設定")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(palette.accent)
                    }

                    ForEach(selections.sorted(by: { $0.defaultPriority > $1.defaultPriority })) { kind in
                        HStack {
                            Image(systemName: kind.symbolName)
                                .foregroundStyle(palette.accent)
                                .accessibilityHidden(true)
                            Text(kind.title)
                            Spacer()
                            Text("\(resolvedTarget(for: kind))回")
                                .font(.subheadline.monospacedDigit().weight(.semibold))
                        }
                    }

                    Divider().overlay(palette.primaryText.opacity(0.08))

                    HStack(spacing: MiraSpacing.sm) {
                        Image(systemName: "clock.fill")
                            .foregroundStyle(palette.accent)
                            .accessibilityHidden(true)
                        Text("予定を入れない基本時間")
                        Spacer()
                        Text(availabilitySummary)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(palette.secondaryText)
                            .multilineTextAlignment(.trailing)
                    }
                }
                .miraCard(palette)
                Spacer(minLength: MiraSpacing.lg)
            }
            .padding(MiraSpacing.lg)
        }
    }

    private var navigationButtons: some View {
        HStack(spacing: MiraSpacing.sm) {
            if step > 0 {
                Button("戻る") { step -= 1 }
                    .font(.headline)
                    .frame(minWidth: 76, minHeight: 52)
                    .foregroundStyle(palette.primaryText)
                    .background(palette.surface, in: RoundedRectangle(cornerRadius: MiraRadius.medium))
                    .buttonStyle(MiraPressStyle())
            }

            PrimaryButton(
                title: step == totalSteps - 1 ? "余白を置いて始める" : "次へ",
                symbol: step == totalSteps - 1 ? "sparkles" : "arrow.right",
                palette: palette,
                isDisabled: step == 1 && selections.isEmpty
            ) {
                if step == totalSteps - 1 {
                    var submittedTargets = targets.filter { selections.contains($0.key) }
                    if marginMode == .automatic {
                        submittedTargets[.freeEvening] = targets[.freeEvening]
                    }
                    store.finishOnboarding(
                        targets: submittedTargets,
                        baseRules: availabilityRules.compactMap(\.domainRule),
                        marginComfort: marginComfort,
                        useRecommendedTargets: marginMode == .automatic
                    )
                } else {
                    step += 1
                }
            }
        }
    }

    private var availabilitySummary: String {
        let enabled = availabilityRules.filter(\.isEnabled)
        guard !enabled.isEmpty else { return "設定なし" }
        let weekdays = Set(enabled.map(\.weekday))
        let standardDays = Set(2...6)
        let standardTime = enabled.allSatisfy { $0.startMinute == 9 * 60 && $0.endMinute == 18 * 60 }
        if weekdays == standardDays && standardTime {
            return "月〜金 9:00–18:00"
        }
        return "\(enabled.count)曜日を設定"
    }

    private func resolvedTarget(for kind: MarginKind) -> Int {
        guard marginMode == .automatic else { return targets[kind, default: 0] }
        if kind == .freeEvening { return targets[kind, default: recommendation.targets[kind, default: 0]] }
        return recommendation.targets[kind, default: targets[kind, default: 0]]
    }

    private func onboardingTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: MiraSpacing.xs) {
            Text(title)
                .font(.title2.bold())
                .foregroundStyle(palette.primaryText)
            Text(subtitle)
                .font(.body)
                .foregroundStyle(palette.secondaryText)
                .lineSpacing(3)
        }
    }

    private func binding(for kind: MarginKind) -> Binding<Int> {
        Binding(
            get: { targets[kind, default: 0] },
            set: { targets[kind] = $0 }
        )
    }
}
