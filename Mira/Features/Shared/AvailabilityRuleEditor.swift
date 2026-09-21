import SwiftUI

struct AvailabilityRuleDraft: Identifiable, Hashable {
    let weekday: Int
    var isEnabled: Bool
    var startMinute: Int
    var endMinute: Int

    var id: Int { weekday }

    static let orderedWeekdays = [2, 3, 4, 5, 6, 7, 1]

    static var standardWeekdays: [AvailabilityRuleDraft] {
        orderedWeekdays.map { weekday in
            AvailabilityRuleDraft(
                weekday: weekday,
                isEnabled: (2...6).contains(weekday),
                startMinute: 9 * 60,
                endMinute: 18 * 60
            )
        }
    }

    static func make(from rules: [BaseAvailabilityRule]) -> [AvailabilityRuleDraft] {
        var rulesByWeekday: [Int: BaseAvailabilityRule] = [:]
        rules.forEach { rulesByWeekday[$0.weekday] = $0 }

        return orderedWeekdays.map { weekday in
            if let rule = rulesByWeekday[weekday] {
                return AvailabilityRuleDraft(
                    weekday: weekday,
                    isEnabled: true,
                    startMinute: rule.startMinute,
                    endMinute: rule.endMinute
                )
            }
            return AvailabilityRuleDraft(
                weekday: weekday,
                isEnabled: false,
                startMinute: 9 * 60,
                endMinute: 18 * 60
            )
        }
    }

    var domainRule: BaseAvailabilityRule? {
        guard isEnabled else { return nil }
        let start = min(max(0, startMinute), 23 * 60)
        let end = min(max(start + 30, endMinute), 23 * 60 + 59)
        return BaseAvailabilityRule(weekday: weekday, startMinute: start, endMinute: end)
    }

    var shortWeekdayTitle: String {
        switch weekday {
        case 1: "日"
        case 2: "月"
        case 3: "火"
        case 4: "水"
        case 5: "木"
        case 6: "金"
        case 7: "土"
        default: "?"
        }
    }

    var longWeekdayTitle: String {
        shortWeekdayTitle + "曜日"
    }
}

struct AvailabilityRuleEditor: View {
    @Binding var rules: [AvailabilityRuleDraft]
    let palette: MiraThemePalette

    var body: some View {
        VStack(alignment: .leading, spacing: MiraSpacing.md) {
            HStack(spacing: MiraSpacing.sm) {
                Button {
                    withAnimation(MiraMotion.standard) {
                        rules = AvailabilityRuleDraft.standardWeekdays
                    }
                } label: {
                    Label("平日 9–18時", systemImage: "briefcase.fill")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)

                Button {
                    withAnimation(MiraMotion.standard) {
                        rules = rules.map { rule in
                            var copy = rule
                            copy.isEnabled = false
                            return copy
                        }
                    }
                } label: {
                    Label("設定なし", systemImage: "circle.slash")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
            }
            .tint(palette.accent)

            VStack(spacing: 0) {
                ForEach($rules) { $rule in
                    AvailabilityRuleRow(rule: $rule, palette: palette)
                    if rule.weekday != 1 {
                        Divider().overlay(palette.primaryText.opacity(0.08))
                    }
                }
            }
            .background(palette.surface, in: RoundedRectangle(cornerRadius: palette.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: palette.cardRadius, style: .continuous)
                    .stroke(palette.isCatSkin ? palette.cardBorder : palette.primaryText.opacity(0.08), lineWidth: 1)
            }
        }
        .environment(\.locale, Locale(identifier: "ja_JP"))
        .environment(\.timeZone, Calendar.mira.timeZone)
    }
}

private struct AvailabilityRuleRow: View {
    @Binding var rule: AvailabilityRuleDraft
    let palette: MiraThemePalette

    var body: some View {
        HStack(spacing: MiraSpacing.sm) {
            Text(rule.shortWeekdayTitle)
                .font(.headline)
                .foregroundStyle(palette.primaryText)
                .frame(width: 28, height: 28)
                .background(dayBackground, in: Circle())
                .accessibilityHidden(true)

            Toggle(rule.longWeekdayTitle, isOn: $rule.isEnabled)
                .labelsHidden()
                .tint(palette.accent)
                .accessibilityLabel(rule.longWeekdayTitle)

            Spacer(minLength: MiraSpacing.xs)

            if rule.isEnabled {
                DatePicker(
                    "開始",
                    selection: startBinding,
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
                .datePickerStyle(.compact)
                .controlSize(.small)
                .fixedSize()
                .accessibilityLabel("\(rule.longWeekdayTitle)の開始時刻")

                Text("–")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.secondaryText)
                    .accessibilityHidden(true)

                DatePicker(
                    "終了",
                    selection: endBinding,
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
                .datePickerStyle(.compact)
                .controlSize(.small)
                .fixedSize()
                .accessibilityLabel("\(rule.longWeekdayTitle)の終了時刻")
            } else {
                Text("設定なし")
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)
                    .frame(minHeight: 44)
            }
        }
        .padding(.horizontal, MiraSpacing.sm)
        .padding(.vertical, 7)
        .frame(minHeight: 60)
        .contentShape(Rectangle())
        .accessibilityElement(children: .contain)
    }

    private var dayBackground: Color {
        switch rule.weekday {
        case 1: palette.critical.opacity(0.14)
        case 7: palette.accentSoft
        default: palette.elevatedSurface
        }
    }

    private var startBinding: Binding<Date> {
        Binding(
            get: { date(for: rule.startMinute) },
            set: { newValue in
                let minute = min(max(0, minute(from: newValue)), 23 * 60)
                rule.startMinute = minute
                if rule.endMinute <= minute {
                    rule.endMinute = min(minute + 60, 23 * 60 + 59)
                }
            }
        )
    }

    private var endBinding: Binding<Date> {
        Binding(
            get: { date(for: rule.endMinute) },
            set: { newValue in
                let minute = min(max(0, minute(from: newValue)), 23 * 60 + 59)
                if minute <= rule.startMinute {
                    rule.startMinute = max(0, minute - 60)
                }
                rule.endMinute = max(rule.startMinute + 30, minute)
            }
        )
    }

    private func date(for minute: Int) -> Date {
        var components = DateComponents()
        components.year = 2001
        components.month = 1
        components.day = 1
        components.hour = max(0, minute) / 60
        components.minute = max(0, minute) % 60
        return Calendar.mira.date(from: components) ?? Date(timeIntervalSinceReferenceDate: 0)
    }

    private func minute(from date: Date) -> Int {
        let components = Calendar.mira.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }
}

struct BaseRulesEditorSheet: View {
    @Environment(MiraStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let palette: MiraThemePalette
    @State private var rules: [AvailabilityRuleDraft]

    init(initialRules: [BaseAvailabilityRule], palette: MiraThemePalette) {
        self.palette = palette
        _rules = State(initialValue: AvailabilityRuleDraft.make(from: initialRules))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: MiraSpacing.lg) {
                    VStack(alignment: .leading, spacing: MiraSpacing.xs) {
                        Text("普段、予定を入れたくない時間")
                            .font(.title2.bold())
                            .foregroundStyle(palette.primaryText)
                        Text("仕事・学校・睡眠などを曜日ごとに設定します。余白や候補日はこの時間を避けます。")
                            .font(.body)
                            .foregroundStyle(palette.secondaryText)
                            .lineSpacing(3)
                    }

                    AvailabilityRuleEditor(rules: $rules, palette: palette)
                }
                .padding(MiraSpacing.md)
                .padding(.bottom, MiraSpacing.xl)
            }
            .miraScreenBackground(palette)
            .navigationTitle("基本時間")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        store.updateBaseRules(rules.compactMap(\.domainRule))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .tint(palette.accent)
    }
}
