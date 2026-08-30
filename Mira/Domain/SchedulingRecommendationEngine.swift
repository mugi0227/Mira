import Foundation

struct SchedulingRecommendationEngine: Sendable {
    private let calendar: Calendar

    init(calendar: Calendar = .mira) {
        self.calendar = calendar
    }

    func recommendations(
        title: String,
        dateRange: DateInterval,
        duration: DurationBucket,
        timeBands: [SchedulingTimeBand],
        items: [CalendarItemSnapshot],
        heldCandidates: [CandidateSlotSnapshot],
        baseRules: [BaseAvailabilityRule],
        limitOverride: Int? = nil
    ) -> [CandidateRecommendation] {
        let bands = timeBands.isEmpty ? duration.selectableBands : timeBands
        let days = candidateDays(in: dateRange)
        let confirmed = items.filter { $0.kind != .margin && $0.kind != .birthday }
        let margins = items.filter { $0.kind == .margin }

        var values: [CandidateRecommendation] = []
        for day in days {
            for band in bands {
                guard duration.selectableBands.contains(band) || band == .allDay else { continue }
                let interval = band.representativeInterval(on: day, duration: duration, calendar: calendar)
                var score = 100.0
                var reasons: [String] = []
                var conflicts: [String] = []

                if overlapsBaseRule(interval: interval, rules: baseRules) {
                    score -= 58
                    conflicts.append("基本的に予定を入れない時間と重なります")
                }

                let confirmedOverlaps = confirmed.filter { $0.occupiedInterval.intersects(interval) }
                if !confirmedOverlaps.isEmpty {
                    score -= 76
                    conflicts.append("確定予定「\(confirmedOverlaps[0].title)」と重なります")
                }

                let marginOverlaps = margins.filter { $0.occupiedInterval.intersects(interval) }
                if !marginOverlaps.isEmpty {
                    score -= 30
                    conflicts.append("守っている余白「\(marginOverlaps[0].title)」を使います")
                }

                let heldOverlaps = heldCandidates.filter { held in
                    guard held.status == .held else { return false }
                    if !calendar.isDate(held.startDate, inSameDayAs: day) { return false }
                    if let heldBand = held.schedulingTimeBand {
                        return heldBand == band || heldBand == .allDay || band == .allDay
                    }
                    return held.interval.intersects(interval)
                }
                if !heldOverlaps.isEmpty {
                    score -= 45
                    conflicts.append("別の日程調整で仮押さえ中です")
                }

                let dayItems = confirmed.filter { calendar.isDate($0.startDate, inSameDayAs: day) }
                let dayLoad = dayItems.map(\.loadClass.score).reduce(0, +)
                if dayLoad == 0 {
                    score += 10
                    reasons.append("同じ日の予定が少ない")
                } else if dayLoad >= 100 {
                    score -= 18
                    reasons.append("同じ日の負荷が高め")
                }

                let previousDay = day.addingDays(-1, calendar: calendar)
                let nextDay = day.addingDays(1, calendar: calendar)
                let neighborHeavy = confirmed.contains {
                    ($0.loadClass >= .heavy) &&
                    (calendar.isDate($0.startDate, inSameDayAs: previousDay) || calendar.isDate($0.startDate, inSameDayAs: nextDay))
                }
                if neighborHeavy {
                    score -= 12
                    reasons.append("前後に重い予定があります")
                } else {
                    score += 6
                    reasons.append("前後の負荷が軽め")
                }

                let weekday = calendar.component(.weekday, from: day)
                if duration == .short, band == .evening, (2...6).contains(weekday) {
                    score += 4
                    reasons.append("平日夜に収まります")
                }
                if duration != .short, weekday == 1 || weekday == 7 {
                    score += 5
                    reasons.append("長めの予定を置きやすい休日")
                }

                if conflicts.isEmpty {
                    reasons.insert("余白と他の予定を守れます", at: 0)
                }

                values.append(CandidateRecommendation(
                    day: day,
                    timeBand: band,
                    durationBucket: duration,
                    score: score,
                    reasons: Array(reasons.prefix(3)),
                    conflicts: conflicts,
                    isRecommended: false
                ))
            }
        }

        let sorted = values.sorted {
            if $0.score != $1.score { return $0.score > $1.score }
            if $0.day != $1.day { return $0.day < $1.day }
            return $0.timeBand.rawValue < $1.timeBand.rawValue
        }

        let recommendationCount = limitOverride ?? recommendedCount(from: sorted, range: dateRange)
        var recommendedIDs: Set<UUID> = []
        var usedDays: Set<Date> = []

        for candidate in sorted {
            guard recommendedIDs.count < recommendationCount else { break }
            let normalizedDay = calendar.startOfDay(for: candidate.day)
            if usedDays.contains(normalizedDay), sorted.count > recommendationCount {
                continue
            }
            if candidate.score < 25, recommendedIDs.count >= 2 { continue }
            recommendedIDs.insert(candidate.id)
            usedDays.insert(normalizedDay)
        }

        if recommendedIDs.count < min(2, recommendationCount) {
            for candidate in sorted where !recommendedIDs.contains(candidate.id) {
                recommendedIDs.insert(candidate.id)
                if recommendedIDs.count >= min(2, recommendationCount) { break }
            }
        }

        return values.map { candidate in
            var copy = candidate
            copy.isRecommended = recommendedIDs.contains(candidate.id)
            return copy
        }
    }

    private func recommendedCount(from sorted: [CandidateRecommendation], range: DateInterval) -> Int {
        let good = sorted.filter { $0.score >= 70 }
        let excellent = sorted.filter { $0.score >= 92 }
        let rangeDays = max(1, calendar.dateComponents([.day], from: range.start, to: range.end).day ?? 1)
        if excellent.count >= 5, rangeDays >= 14 { return 5 }
        if good.count >= 3 { return 3 }
        if sorted.count >= 2 { return 2 }
        return min(1, sorted.count)
    }

    private func candidateDays(in interval: DateInterval) -> [Date] {
        let start = calendar.startOfDay(for: interval.start)
        let inclusiveEnd = calendar.startOfDay(for: interval.end)
        var result: [Date] = []
        var cursor = start
        var safety = 0
        while cursor <= inclusiveEnd, safety < 370 {
            result.append(cursor)
            cursor = cursor.addingDays(1, calendar: calendar)
            safety += 1
        }
        return result
    }

    private func overlapsBaseRule(interval: DateInterval, rules: [BaseAvailabilityRule]) -> Bool {
        let weekday = calendar.component(.weekday, from: interval.start)
        let startMinute = calendar.component(.hour, from: interval.start) * 60 + calendar.component(.minute, from: interval.start)
        let endMinute = calendar.component(.hour, from: interval.end) * 60 + calendar.component(.minute, from: interval.end)
        return rules.contains { rule in
            rule.weekday == weekday && startMinute < rule.endMinute && endMinute > rule.startMinute
        }
    }
}
