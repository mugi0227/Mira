import Foundation
import SwiftData

@MainActor
extension MiraStore {
    var workDayResolver: WorkDayResolver {
        WorkDayResolver(overrides: workDayOverrides,
                        holidays: Set(deviceHolidays.map { Calendar.mira.startOfDay(for: $0.date) }),
                        excludeHolidays: excludeHolidaysFromWorkDays)
    }

    func loadWorkDayOverrides() {
        guard container.schema.entities.contains(where: { $0.name == "WorkDayOverrideEntity" }) else {
            workDayOverrides = [:]
            return
        }
        workDayOverrides = Dictionary((try? context.fetch(FetchDescriptor<WorkDayOverrideEntity>()))?.map {
            ($0.day, $0.isWorkDay)
        } ?? [], uniquingKeysWith: { _, last in last })
    }

    func clearWorkDayOverrides() throws {
        if container.schema.entities.contains(where: { $0.name == "WorkDayOverrideEntity" }) {
            try context.delete(model: WorkDayOverrideEntity.self)
        }
        workDayOverrides = [:]
    }

    func isWorkDay(_ date: Date) -> Bool {
        workDayResolver.isWorkDay(date, rules: fetchBaseRules())
    }

    func setWorkDay(_ date: Date, _ isWorkDay: Bool) {
        let day = Calendar.mira.startOfDay(for: date)
        do {
            let entries = try context.fetch(FetchDescriptor<WorkDayOverrideEntity>())
            for entry in entries where entry.day == day { context.delete(entry) }
            var defaults = workDayResolver
            defaults.overrides = [:]
            if defaults.isWorkDay(day, rules: fetchBaseRules()) != isWorkDay {
                context.insert(WorkDayOverrideEntity(date: day, isWorkDay: isWorkDay))
            }
            try context.save()
            loadWorkDayOverrides()
            recalculateBalance(for: selectedMonth)
        } catch {
            context.rollback()
            toast = "仕事の日を変更できませんでした"
        }
    }

    func setExcludeHolidaysFromWorkDays(_ enabled: Bool) {
        guard let settingsEntity else { return }
        let previous = settingsEntity.excludeHolidaysFromWorkDays
        settingsEntity.excludeHolidaysFromWorkDays = enabled
        do {
            try context.save()
            excludeHolidaysFromWorkDays = enabled
            recalculateBalance(for: selectedMonth)
        } catch {
            settingsEntity.excludeHolidaysFromWorkDays = previous
            toast = "仕事の日の設定を変更できませんでした"
        }
    }
}
