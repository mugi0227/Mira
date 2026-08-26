import Foundation
import UserNotifications

actor NotificationService {
    static let shared = NotificationService()

    func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    func scheduleAdjustmentReminder(
        id: UUID,
        title: String,
        deadline: Date,
        catVoice: Bool
    ) async {
        let content = UNMutableNotificationContent()
        content.title = catVoice ? "返事の期限が近いにゃ" : "日程調整の期限が近づいています"
        content.body = catVoice ? "「\(title)」のお返事を確認するにゃ。" : "「\(title)」の候補日を確認しましょう。"
        content.sound = .default
        let triggerDate = max(Date().addingTimeInterval(60), deadline.addingTimeInterval(-86_400))
        let components = Calendar.mira.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let request = UNNotificationRequest(
            identifier: "adjustment.deadline.\(id.uuidString)",
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    func cancelAdjustmentReminder(id: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["adjustment.deadline.\(id.uuidString)"]
        )
    }
}
