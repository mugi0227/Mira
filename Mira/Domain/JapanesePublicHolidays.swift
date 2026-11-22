import Foundation

enum JapanesePublicHolidays {
    private static let daysByYear: [Int: Set<Int>] = Dictionary(uniqueKeysWithValues: (2000...2099).map { year in
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        func date(_ month: Int, _ day: Int) -> Date {
            calendar.date(from: DateComponents(year: year, month: month, day: day))!
        }
        var holidays = Set<Date>()
        func add(_ month: Int, _ day: Int) { holidays.insert(date(month, day)) }
        func monday(_ month: Int, _ occurrence: Int) {
            let weekday = calendar.component(.weekday, from: date(month, 1))
            add(month, 1 + (9 - weekday) % 7 + 7 * (occurrence - 1))
        }
        add(1, 1)
        monday(1, 2)
        add(2, 11)
        if year >= 2020 { add(2, 23) }
        add(3, Int(20.8431 + 0.242194 * Double(year - 1980)) - (year - 1980) / 4)
        add(4, 29)
        add(5, 3)
        if year >= 2007 { add(5, 4) }
        add(5, 5)
        if year == 2020 {
            add(7, 23); add(7, 24); add(8, 10)
        } else if year == 2021 {
            add(7, 22); add(7, 23); add(8, 8)
        } else {
            if year >= 2003 { monday(7, 3) } else { add(7, 20) }
            if year >= 2016 { add(8, 11) }
            if year >= 2000 { monday(10, 2) }
        }
        if year >= 2003 { monday(9, 3) } else { add(9, 15) }
        add(9, Int(23.2488 + 0.242194 * Double(year - 1980)) - (year - 1980) / 4)
        add(11, 3)
        add(11, 23)
        if year <= 2018 { add(12, 23) }
        if year == 2019 { add(5, 1); add(10, 22) }
        let nationalHolidays = holidays
        for day in nationalHolidays {
            let between = calendar.date(byAdding: .day, value: 1, to: day)!
            let next = calendar.date(byAdding: .day, value: 2, to: day)!
            if nationalHolidays.contains(next), calendar.component(.weekday, from: between) != 1 {
                holidays.insert(between)
            }
        }
        for day in nationalHolidays where calendar.component(.weekday, from: day) == 1 {
            var substitute = calendar.date(byAdding: .day, value: 1, to: day)!
            if year >= 2007 {
                while holidays.contains(substitute) {
                    substitute = calendar.date(byAdding: .day, value: 1, to: substitute)!
                }
            }
            holidays.insert(substitute)
        }
        return (year, Set(holidays.map { calendar.component(.month, from: $0) * 100 + calendar.component(.day, from: $0) }))
    })

    static func isHoliday(_ date: Date, calendar: Calendar = .mira) -> Bool {
        let year = calendar.component(.year, from: date)
        let day = calendar.component(.month, from: date) * 100 + calendar.component(.day, from: date)
        return daysByYear[year]?.contains(day) == true
    }
}
