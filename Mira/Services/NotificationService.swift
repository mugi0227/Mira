import Foundation
import UserNotifications

actor NotificationService {
    static let shared = NotificationService()
    private let router = ReminderNotificationDelegate()
    private let pendingDestinationKey = "mira.reminder.pending-destination"
    private var revisions: [String: Int] = [:]
    private var desiredPlans: [String: ReminderPlan] = [:]

    init() {
        UNUserNotificationCenter.current().delegate = router
        let open = UNNotificationAction(identifier: "mira.open", title: "案件を見る", options: [.foreground])
        let category = UNNotificationCategory(identifier: "mira.reminder", actions: [open], intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    func receive(_ destination: ReminderDestination) async {
        UserDefaults.standard.set(destination.rawValue, forKey: pendingDestinationKey)
        await MainActor.run {
            NotificationCenter.default.post(name: .miraOpenReminder, object: nil)
        }
    }

    func consumePendingDestination() -> ReminderDestination? {
        guard let raw = UserDefaults.standard.string(forKey: pendingDestinationKey) else { return nil }
        UserDefaults.standard.removeObject(forKey: pendingDestinationKey)
        return ReminderDestination(rawValue: raw)
    }

    func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    func schedule(_ plan: ReminderPlan, now: Date = .now) async {
        guard let triggerDate = plan.triggerDate(now: now) else {
            cancel(identifier: plan.identifier)
            return
        }
        revisions[plan.identifier, default: 0] += 1
        desiredPlans[plan.identifier] = plan
        let revision = revisions[plan.identifier]
        let center = UNUserNotificationCenter.current()
        let delivered = await center.deliveredNotifications()
        guard revisions[plan.identifier] == revision else { return }
        if delivered.contains(where: {
            $0.request.identifier == plan.identifier && ($0.request.content.userInfo["deadline"] as? Double) == plan.deadline.timeIntervalSince1970
        }) { return }
        center.removeDeliveredNotifications(withIdentifiers: [plan.identifier])
        let content = UNMutableNotificationContent()
        content.title = plan.destination.kind == .invitation
            ? (plan.catVoice ? "返事を決める時間だにゃ" : "誘いへの返事を確認")
            : (plan.catVoice ? "お返事を確認するにゃ" : "日程調整の返事を確認")
        content.body = "「\(plan.title)」を開いて、次の一歩を決められます。"
        content.sound = .default
        content.categoryIdentifier = "mira.reminder"
        content.userInfo = ["destination": plan.destination.rawValue, "deadline": plan.deadline.timeIntervalSince1970]
        var components = Calendar.mira.dateComponents([.year, .month, .day, .hour, .minute, .second], from: triggerDate)
        components.calendar = Calendar.mira
        components.timeZone = Calendar.mira.timeZone
        let request = UNNotificationRequest(
            identifier: plan.identifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )
        try? await center.add(request)
        if revisions[plan.identifier] != revision {
            if let latest = desiredPlans[plan.identifier] {
                await schedule(latest)
            } else {
                center.removePendingNotificationRequests(withIdentifiers: [plan.identifier])
            }
        }
    }

    func reconcile(_ plans: [ReminderPlan], now: Date = .now) async {
        let baselineRevisions = revisions
        let valid = plans.filter { $0.triggerDate(now: now) != nil }
        let activeIDs = Set(valid.map(\.identifier))
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let delivered = await center.deliveredNotifications()
        let knownIDs = Set(pending.map(\.identifier) + delivered.map { $0.request.identifier } + Array(desiredPlans.keys))
        for id in knownIDs where (id.hasPrefix("adjustment.deadline.") || id.hasPrefix("invitation.deadline.")) && !activeIDs.contains(id) {
            if revisions[id] == baselineRevisions[id] { cancel(identifier: id) }
        }
        for plan in valid where revisions[plan.identifier] == baselineRevisions[plan.identifier] {
            await schedule(plan, now: now)
        }
    }

    func cancelAdjustmentReminder(id: UUID) {
        cancel(identifier: "adjustment.deadline.\(id.uuidString)")
    }

    func cancelInvitationReminder(id: UUID) {
        cancel(identifier: "invitation.deadline.\(id.uuidString)")
    }

    private func cancel(identifier: String) {
        revisions[identifier, default: 0] += 1
        desiredPlans[identifier] = nil
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }
}
