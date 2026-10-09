import SwiftUI
import WidgetKit

@main
struct MiraWidgetBundle: WidgetBundle {
    var body: some Widget {
        MiraTodayWidget()
    }
}

struct MiraTodayEntry: TimelineEntry {
    let date: Date
    let snapshot: MiraWidgetSnapshot
    let isPlaceholder: Bool
}

struct MiraTodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> MiraTodayEntry {
        MiraTodayEntry(date: .now, snapshot: .placeholder, isPlaceholder: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (MiraTodayEntry) -> Void) {
        let snapshot = MiraWidgetSnapshot.load()
        completion(MiraTodayEntry(date: .now, snapshot: snapshot ?? .placeholder, isPlaceholder: snapshot == nil))
    }

    /// One entry now and one each time a plan ends today, so finished plans
    /// drop off without the app running; then refresh after midnight.
    func getTimeline(in context: Context, completion: @escaping (Timeline<MiraTodayEntry>) -> Void) {
        let now = Date()
        let snapshot = MiraWidgetSnapshot.load() ?? MiraWidgetSnapshot(generatedAt: now, entries: [])
        let calendar = MiraWidgetCalendar.calendar
        let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now.addingTimeInterval(3600)
        let changes = snapshot.today(at: now)
            .filter { !$0.isAllDay && $0.end > now && $0.end < midnight }
            .map(\.end)
        let dates = ([now] + changes).sorted()
        let entries = dates.map { MiraTodayEntry(date: $0, snapshot: snapshot, isPlaceholder: false) }
        completion(Timeline(entries: entries, policy: .after(midnight.addingTimeInterval(60))))
    }
}

struct MiraTodayWidget: Widget {
    let kind = "MiraTodayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MiraTodayProvider()) { entry in
            MiraTodayWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(colors: [Color(hex: 0xF4FAFD), Color(hex: 0xE4F2F8)], startPoint: .top, endPoint: .bottom)
                }
        }
        .configurationDisplayName("今日と次の余白")
        .description("今日の予定と、次に守る余白をひと目で。")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

struct MiraTodayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: MiraTodayEntry

    private var today: [MiraWidgetSnapshot.Entry] { entry.snapshot.today(at: entry.date) }
    private var nextMargin: MiraWidgetSnapshot.Entry? { entry.snapshot.nextMargin(after: entry.date) }
    private var nextPlan: MiraWidgetSnapshot.Entry? { entry.snapshot.nextPlan(after: entry.date) }

    var body: some View {
        switch family {
        case .accessoryInline:
            inline
        case .accessoryRectangular:
            rectangular
        case .systemMedium:
            HStack(alignment: .top, spacing: 12) {
                todayList(limit: 4)
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    marginBlock
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        default:
            VStack(alignment: .leading, spacing: 6) {
                todayList(limit: 3)
                Spacer(minLength: 0)
                if let nextMargin {
                    Label(marginText(nextMargin), systemImage: "leaf.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color(hex: 0x3F8F6E))
                        .lineLimit(1)
                }
            }
        }
    }

    private func todayList(limit: Int) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("今日 \(MiraWidgetCalendar.shortDay(entry.date))")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color(hex: 0x2B4A5E))
            if today.isEmpty {
                Text("予定なし。ゆっくりできる日")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(today.prefix(limit)) { item in
                    HStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color(hex: item.tintHex))
                            .frame(width: 3, height: 26)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(item.title)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                            Text(item.isAllDay ? "終日" : MiraWidgetCalendar.time(item.start))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                if today.count > limit {
                    Text("ほか\(today.count - limit)件")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var marginBlock: some View {
        Text("次の余白")
            .font(.caption.weight(.bold))
            .foregroundStyle(Color(hex: 0x3F8F6E))
        if let nextMargin {
            Label(nextMargin.title, systemImage: nextMargin.symbol)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Text(whenText(nextMargin))
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            Text("まだ置いていないよ")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let nextPlan {
                Text("次 \(whenText(nextPlan)) \(nextPlan.title)")
                    .font(.headline)
                    .lineLimit(1)
            } else {
                Text("このあと予定なし")
                    .font(.headline)
            }
            if let nextMargin {
                Label(marginText(nextMargin), systemImage: "leaf.fill")
                    .font(.caption)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var inline: some View {
        if let nextPlan {
            Text("次 \(whenText(nextPlan)) \(nextPlan.title)")
        } else if let nextMargin {
            Label(marginText(nextMargin), systemImage: "leaf.fill")
        } else {
            Text("今日はゆっくり")
        }
    }

    private func whenText(_ item: MiraWidgetSnapshot.Entry) -> String {
        let calendar = MiraWidgetCalendar.calendar
        let day = calendar.isDate(item.start, inSameDayAs: entry.date) ? "" : MiraWidgetCalendar.shortDay(item.start) + " "
        return item.isAllDay ? day + "終日" : day + MiraWidgetCalendar.time(item.start)
    }

    private func marginText(_ item: MiraWidgetSnapshot.Entry) -> String {
        "次の余白 \(whenText(item)) \(item.title)"
    }
}

private extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

#Preview(as: .systemMedium) {
    MiraTodayWidget()
} timeline: {
    MiraTodayEntry(date: .now, snapshot: .placeholder, isPlaceholder: true)
}
