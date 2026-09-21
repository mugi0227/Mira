import Foundation
import UserNotifications

extension Notification.Name {
    static let miraOpenReminder = Notification.Name("mira.open-reminder")
}

struct ReminderDestination: Hashable, Sendable {
    enum Kind: String, Sendable { case adjustment, invitation }
    var kind: Kind
    var id: UUID

    var rawValue: String { "\(kind.rawValue):\(id.uuidString)" }

    init(kind: Kind, id: UUID) {
        self.kind = kind
        self.id = id
    }

    init?(rawValue: String) {
        let parts = rawValue.split(separator: ":", maxSplits: 1)
        guard parts.count == 2, let kind = Kind(rawValue: String(parts[0])), let id = UUID(uuidString: String(parts[1])) else { return nil }
        self.init(kind: kind, id: id)
    }
}

struct ReminderPlan: Sendable {
    var destination: ReminderDestination
    var title: String
    var deadline: Date
    var catVoice: Bool

    var identifier: String { "\(destination.kind.rawValue).deadline.\(destination.id.uuidString)" }

    func triggerDate(now: Date) -> Date? {
        guard deadline > now else { return nil }
        let dayBefore = deadline.addingTimeInterval(-86_400)
        return dayBefore > now ? dayBefore : deadline
    }

    static func adjustment(id: UUID, title: String, status: AdjustmentStatus, deadline: Date?, catVoice: Bool) -> ReminderPlan? {
        guard status == .waiting, let deadline else { return nil }
        return ReminderPlan(destination: ReminderDestination(kind: .adjustment, id: id), title: title, deadline: deadline, catVoice: catVoice)
    }

    static func invitation(id: UUID, title: String, status: InvitationStatus, deadline: Date?, catVoice: Bool) -> ReminderPlan? {
        guard status == .considering, let deadline else { return nil }
        return ReminderPlan(destination: ReminderDestination(kind: .invitation, id: id), title: title, deadline: deadline, catVoice: catVoice)
    }
}

final class ReminderNotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        guard response.actionIdentifier != UNNotificationDismissActionIdentifier,
              let rawValue = response.notification.request.content.userInfo["destination"] as? String,
              let destination = ReminderDestination(rawValue: rawValue) else {
            completionHandler()
            return
        }
        Task {
            await NotificationService.shared.receive(destination)
            completionHandler()
        }
    }
}
