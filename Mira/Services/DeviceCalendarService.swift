import EventKit
import Foundation
import Observation

@MainActor
@Observable
final class DeviceCalendarService {
    let eventStore = EKEventStore()
    private let defaults: UserDefaults
    var enabled: Bool {
        didSet { defaults.set(enabled, forKey: "mira.calendar.enabled") }
    }
    var selectedIDs: Set<String> {
        didSet { defaults.set(Array(selectedIDs), forKey: "mira.calendar.selected") }
    }
    var destinationID: String {
        didSet { defaults.set(destinationID, forKey: "mira.calendar.destination") }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        enabled = defaults.bool(forKey: "mira.calendar.enabled")
        selectedIDs = Set(defaults.stringArray(forKey: "mira.calendar.selected") ?? [])
        destinationID = defaults.string(forKey: "mira.calendar.destination") ?? ""
    }

    var hasAccess: Bool { EKEventStore.authorizationStatus(for: .event) == .fullAccess }

    func requestAccess() async -> Bool {
        if hasAccess { return true }
        return (try? await eventStore.requestFullAccessToEvents()) == true
    }

    var calendars: [DeviceCalendarOption] {
        guard hasAccess else { return [] }
        return eventStore.calendars(for: .event).map {
            DeviceCalendarOption(id: $0.calendarIdentifier, title: $0.title, canWrite: $0.allowsContentModifications)
        }.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    func read(in interval: DateInterval) throws -> [DeviceCalendarEvent] {
        guard hasAccess else { throw CalendarConnectionError.access }
        let calendars = eventStore.calendars(for: .event).filter { selectedIDs.contains($0.calendarIdentifier) }
        guard !calendars.isEmpty else { return [] }
        let predicate = eventStore.predicateForEvents(withStart: interval.start, end: interval.end, calendars: calendars)
        return eventStore.events(matching: predicate).filter { $0.status != .canceled }.compactMap { event in
            guard let reference = reference(for: event), event.endDate > event.startDate else { return nil }
            let localID = defaults.string(forKey: "mira.calendar.link.\(reference.key)").flatMap(UUID.init(uuidString:))
            return DeviceCalendarEvent(reference: reference, title: event.title ?? "予定", start: event.startDate,
                                       end: event.endDate, allDay: event.isAllDay, localID: localID)
        }
    }

    /// An export is always an explicit user action. Existing device events are edited in Calendar UI.
    func export(_ item: CalendarItemSnapshot) throws -> DeviceEventReference {
        guard enabled, hasAccess else { throw CalendarConnectionError.access }
        guard let calendar = eventStore.calendar(withIdentifier: destinationID), calendar.allowsContentModifications else {
            throw CalendarConnectionError.destination
        }
        // Recover an earlier export even if the local persistence failed after EventKit succeeded.
        let marker = URL(string: "mira://event/\(item.id.uuidString)")
        let search = eventStore.predicateForEvents(withStart: item.startDate.addingDays(-1),
            end: item.endDate.addingDays(1), calendars: [calendar])
        let existing = eventStore.events(matching: search).first { $0.url == marker }
        let event = existing ?? EKEvent(eventStore: eventStore)
        event.calendar = calendar
        event.title = item.title
        event.startDate = item.startDate
        event.endDate = item.endDate
        event.isAllDay = item.isAllDay
        event.url = marker
        try eventStore.save(event, span: .thisEvent, commit: true)
        guard let reference = reference(for: event) else { throw CalendarConnectionError.unavailable }
        defaults.set(item.id.uuidString, forKey: "mira.calendar.link.\(reference.key)")
        selectedIDs.insert(calendar.calendarIdentifier)
        return reference
    }

    func event(for reference: DeviceEventReference) -> EKEvent? {
        guard hasAccess, let calendar = eventStore.calendar(withIdentifier: reference.calendarID) else { return nil }
        if !reference.isRecurring { return eventStore.event(withIdentifier: reference.eventID) }
        let predicate = eventStore.predicateForEvents(withStart: reference.occurrenceStart.addingTimeInterval(-1),
            end: reference.occurrenceStart.addingDays(1), calendars: [calendar])
        return eventStore.events(matching: predicate).first {
            $0.eventIdentifier == reference.eventID && abs($0.startDate.timeIntervalSince(reference.occurrenceStart)) < 1
        }
    }

    private func reference(for event: EKEvent) -> DeviceEventReference? {
        guard let id = event.eventIdentifier, let calendarID = event.calendar?.calendarIdentifier else { return nil }
        return DeviceEventReference(eventID: id, calendarID: calendarID, occurrenceStart: event.startDate,
                                    isRecurring: event.hasRecurrenceRules, modifiedAt: event.lastModifiedDate)
    }
}

enum CalendarConnectionError: LocalizedError {
    case access, destination, unavailable
    var errorDescription: String? {
        switch self {
        case .access: "設定アプリでカレンダーのフルアクセスを許可してください。"
        case .destination: "書き込み可能な保存先カレンダーを選んでください。"
        case .unavailable: "予定を確認できませんでした。カレンダーを更新して再度お試しください。"
        }
    }
}
