import Foundation
import SwiftData

@MainActor
extension MiraStore {
    func setCalendarConnectionEnabled(_ enabled: Bool) async {
        if enabled, !deviceCalendarService.hasAccess {
            guard await deviceCalendarService.requestAccess() else {
                calendarSyncStatus = CalendarConnectionError.access.localizedDescription
                return
            }
        }
        deviceCalendarService.enabled = enabled
        if !enabled {
            calendarSyncStatus = "接続を停止しました。読み込み済みの予定は残っています。"
            return
        }
        if enabled, deviceCalendarService.selectedIDs.isEmpty {
            calendarSyncStatus = "読み込むカレンダーを選んでください"
        }
        await refreshDeviceCalendar()
    }

    func refreshDeviceCalendar(around month: Date? = nil, through end: Date? = nil) async {
        guard !isEmergencyStorage, !isSyncingCalendar, !demoModeEnabled else { return }
        guard deviceCalendarService.enabled else { return }
        isSyncingCalendar = true
        defer { isSyncingCalendar = false }
        do {
            let anchor = month ?? selectedMonth
            let interval = DateInterval(start: MonthKey(date: anchor.addingMonths(-1)).firstDay,
                end: MonthKey(date: max(anchor, end ?? anchor).addingMonths(2)).firstDay)
            let events = try deviceCalendarService.read(in: interval)
            let entities = try context.fetch(FetchDescriptor<CalendarItemEntity>())
            let imported = entities.filter { $0.snapshot.deviceEvent != nil }
            var byKey: [String: CalendarItemEntity] = [:]
            for entity in imported {
                if let key = entity.snapshot.deviceEvent?.key { byKey[key] = entity }
            }
            let incomingKeys = Set(events.map { $0.reference.key })
            for event in events {
                let existing = byKey[event.reference.key] ?? entities.first { $0.id == event.localID }
                let load = loadEngine.evaluate(title: event.title, startDate: event.start, endDate: event.end,
                    isAllDay: event.allDay, explicitRules: fetchLoadRules())
                var value = existing?.snapshot ?? CalendarItemSnapshot(id: event.localID ?? UUID(), title: event.title,
                    startDate: event.start, endDate: event.end, isAllDay: event.allDay, kind: .confirmed, marginKind: nil,
                    loadClass: load.loadClass, loadReason: load.reason, bufferBeforeMinutes: load.bufferBeforeMinutes,
                    bufferAfterMinutes: load.bufferAfterMinutes, isImportantTime: false, sourceID: nil)
                value.title = event.title
                value.startDate = event.start
                value.endDate = event.end
                value.isAllDay = event.allDay
                value.deviceEvent = event.reference
                if existing?.loadReason != "あなたが明示的に変更した負荷" {
                    value.loadClass = load.loadClass
                    value.loadReason = load.reason
                    value.bufferBeforeMinutes = load.bufferBeforeMinutes
                    value.bufferAfterMinutes = load.bufferAfterMinutes
                }
                if let existing { existing.apply(value) } else { context.insert(CalendarItemEntity(snapshot: value)) }
            }
            for entity in imported {
                guard let reference = entity.snapshot.deviceEvent else { continue }
                let wasInRange = entity.startDate < interval.end && entity.endDate > interval.start
                if !deviceCalendarService.selectedIDs.contains(reference.calendarID) || (wasInRange && !incomingKeys.contains(reference.key)) {
                    context.delete(entity)
                }
            }
            try context.save()
            try refresh()
            updateMarginRecommendation(for: selectedMonth)
            recalculateBalance(for: selectedMonth)
            calendarSyncStatus = events.isEmpty ? "この期間の予定はありません" : "\(events.count)件の予定を確認しました"
        } catch {
            context.rollback()
            calendarSyncStatus = "更新できませんでした。保存済みの予定を表示しています。\(error.localizedDescription)"
        }
    }

    @discardableResult
    func exportToDeviceCalendar(_ item: CalendarItemSnapshot) -> Bool {
        guard !demoModeEnabled, item.kind == .confirmed, item.deviceEvent == nil else { return false }
        do {
            guard let entity = try entity(id: item.id) else { return false }
            guard entity.snapshot.deviceEvent == nil, entity.endDate > entity.startDate else { return false }
            let reference = try deviceCalendarService.export(entity.snapshot)
            var value = entity.snapshot
            value.deviceEvent = reference
            entity.apply(value)
            try context.save()
            try refresh()
            undoEntry = nil
            toast = "iPhoneのカレンダーへ保存しました"
            return true
        } catch {
            context.rollback()
            persistenceIssue = "カレンダーとの接続を完了できませんでした。再試行してください。\(error.localizedDescription)"
            return false
        }
    }
}
