import EventKit
import Foundation

struct DeviceHolidaySnapshot: Identifiable, Hashable, Sendable {
    var id: String { "\(calendarIdentifier)|\(date.timeIntervalSince1970)|\(title)" }
    let date: Date
    let title: String
    let calendarIdentifier: String
}

@MainActor
final class DeviceHolidayService {
    private let eventStore = EKEventStore()

    var hasFullAccess: Bool {
        EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    func requestAccessIfNeeded() async -> Bool {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess:
            return true
        case .notDetermined:
            return (try? await eventStore.requestFullAccessToEvents()) == true
        case .denied, .restricted, .writeOnly:
            return false
        @unknown default:
            return false
        }
    }

    func holidays(around month: Date) -> [DeviceHolidaySnapshot] {
        guard hasFullAccess else { return [] }
        let calendars = eventStore.calendars(for: .event).filter(isHolidayCalendar)
        guard !calendars.isEmpty else { return [] }

        let monthInterval = MonthKey(date: month).interval
        let start = monthInterval.start.addingDays(-7)
        let end = monthInterval.end.addingDays(7)
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: calendars)
        let events = eventStore.events(matching: predicate)
            .filter(\.isAllDay)
            .sorted { $0.startDate < $1.startDate }

        var seen: Set<String> = []
        return events.compactMap { event in
            let date = Calendar.mira.startOfDay(for: event.startDate)
            let trimmedTitle = event.title?.trimmingCharacters(in: .whitespacesAndNewlines)
            let title = trimmedTitle.flatMap { $0.isEmpty ? nil : $0 } ?? "祝日"
            let key = "\(date.timeIntervalSince1970)|\(title)"
            guard seen.insert(key).inserted else { return nil }
            return DeviceHolidaySnapshot(
                date: date,
                title: title,
                calendarIdentifier: event.calendar?.calendarIdentifier ?? "device-holiday"
            )
        }
    }

    private func isHolidayCalendar(_ calendar: EKCalendar) -> Bool {
        let title = calendar.title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let looksLikeHoliday = ["祝日", "holiday", "holidays in japan", "japanese holidays"]
            .contains { title.localizedCaseInsensitiveContains($0) }
        return looksLikeHoliday && (calendar.isSubscribed || calendar.type == .subscription)
    }
}
