import Foundation

enum JapanesePublicHolidays {
    private static let daysByYear: [Int: [Int: String]] = Dictionary(uniqueKeysWithValues: (2000...2099).map { year in
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        func date(_ month: Int, _ day: Int) -> Date {
            calendar.date(from: DateComponents(year: year, month: month, day: day))!
        }
        var holidays: [Date: String] = [:]
        func add(_ month: Int, _ day: Int, _ title: String) { holidays[date(month, day)] = title }
        func monday(_ month: Int, _ occurrence: Int, _ title: String) {
            let weekday = calendar.component(.weekday, from: date(month, 1))
            add(month, 1 + (9 - weekday) % 7 + 7 * (occurrence - 1), title)
        }
        add(1, 1, "元日")
        monday(1, 2, "成人の日")
        add(2, 11, "建国記念の日")
        if year >= 2020 { add(2, 23, "天皇誕生日") }
        add(3, Int(20.8431 + 0.242194 * Double(year - 1980)) - (year - 1980) / 4, "春分の日")
        add(4, 29, year >= 2007 ? "昭和の日" : "みどりの日")
        add(5, 3, "憲法記念日")
        if year >= 2007 { add(5, 4, "みどりの日") }
        add(5, 5, "こどもの日")
        if year == 2020 {
            add(7, 23, "海の日"); add(7, 24, "スポーツの日"); add(8, 10, "山の日")
        } else if year == 2021 {
            add(7, 22, "海の日"); add(7, 23, "スポーツの日"); add(8, 8, "山の日")
        } else {
            if year >= 2003 { monday(7, 3, "海の日") } else { add(7, 20, "海の日") }
            if year >= 2016 { add(8, 11, "山の日") }
            monday(10, 2, year >= 2020 ? "スポーツの日" : "体育の日")
        }
        if year >= 2003 { monday(9, 3, "敬老の日") } else { add(9, 15, "敬老の日") }
        add(9, Int(23.2488 + 0.242194 * Double(year - 1980)) - (year - 1980) / 4, "秋分の日")
        add(11, 3, "文化の日")
        add(11, 23, "勤労感謝の日")
        if year <= 2018 { add(12, 23, "天皇誕生日") }
        if year == 2019 { add(5, 1, "天皇の即位の日"); add(10, 22, "即位礼正殿の儀の行われる日") }
        let nationalHolidays = Set(holidays.keys)
        for day in nationalHolidays {
            let between = calendar.date(byAdding: .day, value: 1, to: day)!
            let next = calendar.date(byAdding: .day, value: 2, to: day)!
            if nationalHolidays.contains(next), calendar.component(.weekday, from: between) != 1 {
                if holidays[between] == nil { holidays[between] = "国民の休日" }
            }
        }
        for day in nationalHolidays where calendar.component(.weekday, from: day) == 1 {
            var substitute = calendar.date(byAdding: .day, value: 1, to: day)!
            if year >= 2007 {
                while holidays[substitute] != nil {
                    substitute = calendar.date(byAdding: .day, value: 1, to: substitute)!
                }
            }
            if holidays[substitute] == nil { holidays[substitute] = "振替休日" }
        }
        return (year, Dictionary(uniqueKeysWithValues: holidays.map { date, title in
            (calendar.component(.month, from: date) * 100 + calendar.component(.day, from: date), title)
        }))
    })

    static func isHoliday(_ date: Date, calendar: Calendar = .mira) -> Bool {
        title(on: date, calendar: calendar) != nil
    }

    static func title(on date: Date, calendar: Calendar = .mira) -> String? {
        let year = calendar.component(.year, from: date)
        let day = calendar.component(.month, from: date) * 100 + calendar.component(.day, from: date)
        return daysByYear[year]?[day]
    }
}
