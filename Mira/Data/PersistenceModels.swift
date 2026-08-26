import Foundation
import SwiftData

@Model
final class AppSettingsEntity {
    @Attribute(.unique) var key: String
    var onboardingCompleted: Bool
    var themeRaw: String
    var assistantEnabled: Bool
    var characterNotificationsEnabled: Bool
    var notificationsEnabled: Bool
    var demoModeEnabled: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        key: String = "main",
        onboardingCompleted: Bool = false,
        themeRaw: String = AppThemeKind.pixelCat.rawValue,
        assistantEnabled: Bool = true,
        characterNotificationsEnabled: Bool = true,
        notificationsEnabled: Bool = false,
        demoModeEnabled: Bool = true
    ) {
        self.key = key
        self.onboardingCompleted = onboardingCompleted
        self.themeRaw = themeRaw
        self.assistantEnabled = assistantEnabled
        self.characterNotificationsEnabled = characterNotificationsEnabled
        self.notificationsEnabled = notificationsEnabled
        self.demoModeEnabled = demoModeEnabled
        self.createdAt = .now
        self.updatedAt = .now
    }
}

@Model
final class CalendarItemEntity {
    @Attribute(.unique) var id: UUID
    var title: String
    var startDate: Date
    var endDate: Date
    var isAllDay: Bool
    var kindRaw: String
    var marginKindRaw: String?
    var loadRaw: String
    var loadReason: String
    var bufferBeforeMinutes: Int
    var bufferAfterMinutes: Int
    var isImportantTime: Bool
    var sourceID: UUID?
    var createdAt: Date
    var updatedAt: Date

    init(snapshot: CalendarItemSnapshot) {
        id = snapshot.id
        title = snapshot.title
        startDate = snapshot.startDate
        endDate = snapshot.endDate
        isAllDay = snapshot.isAllDay
        kindRaw = snapshot.kind.rawValue
        marginKindRaw = snapshot.marginKind?.rawValue
        loadRaw = snapshot.loadClass.rawValue
        loadReason = snapshot.loadReason
        bufferBeforeMinutes = snapshot.bufferBeforeMinutes
        bufferAfterMinutes = snapshot.bufferAfterMinutes
        isImportantTime = snapshot.isImportantTime
        sourceID = snapshot.sourceID
        createdAt = .now
        updatedAt = .now
    }

    var snapshot: CalendarItemSnapshot {
        CalendarItemSnapshot(
            id: id,
            title: title,
            startDate: startDate,
            endDate: endDate,
            isAllDay: isAllDay,
            kind: CalendarItemKind(rawValue: kindRaw) ?? .confirmed,
            marginKind: marginKindRaw.flatMap(MarginKind.init(rawValue:)),
            loadClass: LoadClass(rawValue: loadRaw) ?? .normal,
            loadReason: loadReason,
            bufferBeforeMinutes: bufferBeforeMinutes,
            bufferAfterMinutes: bufferAfterMinutes,
            isImportantTime: isImportantTime,
            sourceID: sourceID
        )
    }

    func apply(_ snapshot: CalendarItemSnapshot) {
        title = snapshot.title
        startDate = snapshot.startDate
        endDate = snapshot.endDate
        isAllDay = snapshot.isAllDay
        kindRaw = snapshot.kind.rawValue
        marginKindRaw = snapshot.marginKind?.rawValue
        loadRaw = snapshot.loadClass.rawValue
        loadReason = snapshot.loadReason
        bufferBeforeMinutes = snapshot.bufferBeforeMinutes
        bufferAfterMinutes = snapshot.bufferAfterMinutes
        isImportantTime = snapshot.isImportantTime
        sourceID = snapshot.sourceID
        updatedAt = .now
    }
}

@Model
final class MarginGoalEntity {
    @Attribute(.unique) var id: UUID
    var year: Int
    var month: Int
    var kindRaw: String
    var targetCount: Int
    var durationHours: Int
    var priority: Int
    var isEnabled: Bool

    init(snapshot: MarginGoalSnapshot) {
        id = snapshot.id
        year = snapshot.year
        month = snapshot.month
        kindRaw = snapshot.kind.rawValue
        targetCount = snapshot.targetCount
        durationHours = snapshot.durationHours
        priority = snapshot.priority
        isEnabled = snapshot.isEnabled
    }

    var snapshot: MarginGoalSnapshot {
        MarginGoalSnapshot(
            id: id,
            year: year,
            month: month,
            kind: MarginKind(rawValue: kindRaw) ?? .custom,
            targetCount: targetCount,
            durationHours: durationHours,
            priority: priority,
            isEnabled: isEnabled
        )
    }
}

@Model
final class BaseRuleEntity {
    @Attribute(.unique) var id: UUID
    var weekday: Int
    var startMinute: Int
    var endMinute: Int

    init(id: UUID = UUID(), weekday: Int, startMinute: Int, endMinute: Int) {
        self.id = id
        self.weekday = weekday
        self.startMinute = startMinute
        self.endMinute = endMinute
    }

    var snapshot: BaseAvailabilityRule {
        BaseAvailabilityRule(weekday: weekday, startMinute: startMinute, endMinute: endMinute)
    }
}

@Model
final class AdjustmentEntity {
    @Attribute(.unique) var id: UUID
    var title: String
    var contactName: String?
    var responseDeadline: Date?
    var statusRaw: String
    @Attribute(.externalStorage) var candidatesData: Data
    var generatedMessage: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        contactName: String? = nil,
        responseDeadline: Date? = nil,
        status: AdjustmentStatus = .waiting,
        candidates: [CandidateSlotSnapshot],
        generatedMessage: String
    ) {
        self.id = id
        self.title = title
        self.contactName = contactName
        self.responseDeadline = responseDeadline
        self.statusRaw = status.rawValue
        self.candidatesData = (try? JSONEncoder().encode(candidates)) ?? Data()
        self.generatedMessage = generatedMessage
        self.createdAt = .now
        self.updatedAt = .now
    }

    var status: AdjustmentStatus {
        get { AdjustmentStatus(rawValue: statusRaw) ?? .waiting }
        set { statusRaw = newValue.rawValue }
    }

    var candidates: [CandidateSlotSnapshot] {
        get { (try? JSONDecoder().decode([CandidateSlotSnapshot].self, from: candidatesData)) ?? [] }
        set {
            candidatesData = (try? JSONEncoder().encode(newValue)) ?? Data()
            updatedAt = .now
        }
    }
}

@Model
final class PendingInvitationEntity {
    @Attribute(.unique) var id: UUID
    var title: String
    var contactName: String?
    var memo: String?
    var replyDeadline: Date?
    var statusRaw: String
    @Attribute(.externalStorage) var candidatesData: Data
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        contactName: String? = nil,
        memo: String? = nil,
        replyDeadline: Date? = nil,
        status: InvitationStatus = .considering,
        candidates: [CandidateSlotSnapshot]
    ) {
        self.id = id
        self.title = title
        self.contactName = contactName
        self.memo = memo
        self.replyDeadline = replyDeadline
        self.statusRaw = status.rawValue
        self.candidatesData = (try? JSONEncoder().encode(candidates)) ?? Data()
        self.createdAt = .now
        self.updatedAt = .now
    }

    var status: InvitationStatus {
        get { InvitationStatus(rawValue: statusRaw) ?? .considering }
        set { statusRaw = newValue.rawValue }
    }

    var candidates: [CandidateSlotSnapshot] {
        get { (try? JSONDecoder().decode([CandidateSlotSnapshot].self, from: candidatesData)) ?? [] }
        set {
            candidatesData = (try? JSONEncoder().encode(newValue)) ?? Data()
            updatedAt = .now
        }
    }
}

@Model
final class LoadRuleEntity {
    @Attribute(.unique) var id: UUID
    var keyword: String
    var loadRaw: String
    var createdAt: Date

    init(id: UUID = UUID(), keyword: String, loadClass: LoadClass) {
        self.id = id
        self.keyword = keyword
        self.loadRaw = loadClass.rawValue
        self.createdAt = .now
    }

    var snapshot: LoadRule {
        LoadRule(keyword: keyword, loadClass: LoadClass(rawValue: loadRaw) ?? .normal)
    }
}

@Model
final class ImportantPersonEntity {
    @Attribute(.unique) var id: UUID
    var name: String
    var monthlyTarget: Int?
    var targetEnabled: Bool
    var isArchived: Bool

    init(id: UUID = UUID(), name: String, monthlyTarget: Int? = nil, targetEnabled: Bool = false) {
        self.id = id
        self.name = name
        self.monthlyTarget = monthlyTarget
        self.targetEnabled = targetEnabled
        self.isArchived = false
    }
}
