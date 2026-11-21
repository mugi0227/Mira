import Foundation

struct WorkDayResolver: Sendable {
    var overrides: [Date: Bool] = [:]
    var holidays: Set<Date> = []
    var excludeHolidays = true

    func isWorkDay(_ date: Date, rules: [BaseAvailabilityRule], calendar: Calendar = .mira) -> Bool {
        let day = calendar.startOfDay(for: date)
        if let override = overrides[day] { return override }
        return rules.contains { $0.weekday == calendar.component(.weekday, from: day) }
            && !(excludeHolidays && holidays.contains(day))
    }

    func effectiveRules(on date: Date, rules: [BaseAvailabilityRule], calendar: Calendar = .mira) -> [BaseAvailabilityRule] {
        guard isWorkDay(date, rules: rules, calendar: calendar) else { return [] }
        let weekday = calendar.component(.weekday, from: date)
        let matching = rules.filter { $0.weekday == weekday }
        if !matching.isEmpty { return matching }
        let firstMondayOrderedRuleWeekday = [2, 3, 4, 5, 6, 7, 1].first { day in rules.contains { $0.weekday == day } }
        return rules.filter { $0.weekday == firstMondayOrderedRuleWeekday }.map {
            BaseAvailabilityRule(weekday: weekday, startMinute: $0.startMinute, endMinute: $0.endMinute)
        }
    }

    func intervals(on date: Date, rules: [BaseAvailabilityRule], calendar: Calendar = .mira) -> [DateInterval] {
        let day = calendar.startOfDay(for: date)
        return effectiveRules(on: date, rules: rules, calendar: calendar).compactMap { rule in
            let lower = max(0, min(1440, rule.startMinute))
            let upper = max(0, min(1440, rule.endMinute))
            guard upper > lower,
                  let start = calendar.date(byAdding: .minute, value: lower, to: day),
                  let end = calendar.date(byAdding: .minute, value: upper, to: day) else { return nil }
            return DateInterval(start: start, end: end)
        }
    }
}
