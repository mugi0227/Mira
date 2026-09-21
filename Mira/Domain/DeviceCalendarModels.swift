import Foundation

struct DeviceEventReference: Codable, Hashable, Sendable {
    var eventID: String
    var calendarID: String
    var occurrenceStart: Date
    var isRecurring: Bool
    var modifiedAt: Date?

    var key: String {
        let occurrence = isRecurring ? "|\(occurrenceStart.timeIntervalSince1970)" : ""
        return "\(calendarID)|\(eventID)\(occurrence)"
    }
}

struct DeviceCalendarOption: Identifiable, Sendable {
    var id: String
    var title: String
    var canWrite: Bool
}

struct DeviceCalendarEvent: Sendable {
    var reference: DeviceEventReference
    var title: String
    var start: Date
    var end: Date
    var allDay: Bool
    var localID: UUID?
}
