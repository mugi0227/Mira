import SwiftUI

struct AvailabilityShareSheet: View {
    @Environment(MiraStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let palette: MiraThemePalette

    @State private var weekdayEvenings = true
    @State private var weekendAfternoons = true
    @State private var weekendEvenings = true
    @State private var minimumHours = 2

    private let engine = AvailabilityShareEngine()

    var body: some View {
        let days = store.shareDays(rule: rule)
        let text = engine.shareText(for: days)

        NavigationStack {
            List {
                Section {
                    Toggle("平日の夜", isOn: $weekdayEvenings)
                    Toggle("休日の昼", isOn: $weekendAfternoons)
                    Toggle("休日の夜", isOn: $weekendEvenings)
                    Stepper("\(minimumHours)時間以上空いている時だけ", value: $minimumHours, in: 1...4)
                } header: {
                    Text("見せる時間")
                } footer: {
                    Text("これから2週間が対象です。自分のための時間も「予定あり」として守られます。")
                }
                .listRowBackground(palette.surface)

                Section {
                    ForEach(days.filter { !$0.blocks.isEmpty }, id: \.date) { day in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(engine.dayLabel(day.date))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(palette.primaryText)
                            ForEach(day.blocks, id: \.interval) { block in
                                HStack {
                                    Text("\(engine.timeLabel(block.interval.start))〜\(engine.timeLabel(block.interval.end))")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(palette.secondaryText)
                                    Spacer()
                                    Text(block.state.label)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(block.state == .free ? palette.success : palette.secondaryText)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(
                                            (block.state == .free ? palette.success : palette.secondaryText).opacity(0.14),
                                            in: Capsule()
                                        )
                                }
                                .accessibilityElement(children: .combine)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("相手から見える表示")
                } footer: {
                    Text("予定の名前・相手・中身は共有されません。")
                }
                .listRowBackground(palette.surface)

                Section("共有する文") {
                    Text(text)
                        .font(.subheadline)
                        .foregroundStyle(palette.primaryText)
                        .textSelection(.enabled)
                    ShareLink(item: text) {
                        Label("共有する", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .foregroundStyle(palette.accent)
                    }
                }
                .listRowBackground(palette.surface)
            }
            .scrollContentBackground(.hidden)
            .background(palette.background)
            .navigationTitle("空き枠を共有")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private var rule: AvailabilityShareRule {
        var weekendBands = Set<TimeOfDayKind>()
        if weekendAfternoons { weekendBands.insert(.afternoon) }
        if weekendEvenings { weekendBands.insert(.evening) }
        return AvailabilityShareRule(
            startDate: store.now,
            days: 14,
            bands: weekdayEvenings ? [.evening] : [],
            weekendBands: weekendBands,
            minimumHours: minimumHours
        )
    }
}
