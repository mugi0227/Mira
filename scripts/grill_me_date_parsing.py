#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / "Mira/Services/ConversationAssistantService.swift"
text = PATH.read_text(encoding="utf-8")

old = '''        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
'''
new = '''        let normalized = text
            .folding(options: [.widthInsensitive], locale: Locale(identifier: "ja_JP"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
'''
if old in text:
    text = text.replace(old, new, 1)

old = '''        if text.contains("今月") {
            let key = MonthKey(date: now, calendar: calendar)
            return DateInterval(start: max(startOfToday, key.firstDay), end: key.interval.end.addingTimeInterval(-1))
        }
        return DateInterval(start: startOfToday, end: startOfToday.addingDays(28, calendar: calendar).setting(hour: 23, minute: 59, calendar: calendar))
'''
new = '''        if text.contains("明日") {
            let start = startOfToday.addingDays(1, calendar: calendar)
            return DateInterval(start: start, end: start.setting(hour: 23, minute: 59, calendar: calendar))
        }
        if text.contains("今日") {
            return DateInterval(start: startOfToday, end: startOfToday.setting(hour: 23, minute: 59, calendar: calendar))
        }
        if text.contains("今週") {
            let end = startOfWeek(containing: now).addingDays(6, calendar: calendar).setting(hour: 23, minute: 59, calendar: calendar)
            return DateInterval(start: startOfToday, end: max(startOfToday, end))
        }
        if text.contains("今月") {
            let key = MonthKey(date: now, calendar: calendar)
            return DateInterval(start: max(startOfToday, key.firstDay), end: key.interval.end.addingTimeInterval(-1))
        }
        return DateInterval(start: startOfToday, end: startOfToday.addingDays(28, calendar: calendar).setting(hour: 23, minute: 59, calendar: calendar))
'''
if old in text:
    text = text.replace(old, new, 1)

# Add slash/hyphen dates and relative dates before weekday processing.
marker = '''        let weekdayMap: [(String, Int)] = [
'''
addition = '''        if let regex = try? NSRegularExpression(pattern: "(\\d{1,2})[/-](\\d{1,2})") {
            let nsText = text as NSString
            for match in regex.matches(in: text, range: NSRange(location: 0, length: nsText.length)) {
                guard let month = Int(nsText.substring(with: match.range(at: 1))),
                      let day = Int(nsText.substring(with: match.range(at: 2))) else { continue }
                var components = DateComponents(year: currentYear, month: month, day: day)
                if let date = calendar.date(from: components) {
                    if date < calendar.startOfDay(for: now) { components.year = currentYear + 1 }
                    if let adjusted = calendar.date(from: components) { result.append(adjusted) }
                }
            }
        }

        if text.contains("今日") {
            result.append(calendar.startOfDay(for: now))
        }
        if text.contains("明日") {
            result.append(calendar.startOfDay(for: now).addingDays(1, calendar: calendar))
        }
        if text.contains("明後日") {
            result.append(calendar.startOfDay(for: now).addingDays(2, calendar: calendar))
        }

'''
if addition not in text and marker in text:
    text = text.replace(marker, addition + marker, 1)

start = text.find("    private func parseExactTime(")
end = text.find("\n    private func inferTitle", start)
if start >= 0 and end > start:
    replacement = '''    private func parseExactTime(from text: String, dates: [Date], range: DateInterval) -> DateInterval? {
        var hour: Int?
        var minute = 0

        if let regex = try? NSRegularExpression(pattern: "(\\d{1,2})時(半)?"),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let hourRange = Range(match.range(at: 1), in: text) {
            hour = Int(text[hourRange])
            minute = match.range(at: 2).location == NSNotFound ? 0 : 30
        } else if let regex = try? NSRegularExpression(pattern: "(\\d{1,2}):(\\d{2})"),
                  let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                  let hourRange = Range(match.range(at: 1), in: text),
                  let minuteRange = Range(match.range(at: 2), in: text) {
            hour = Int(text[hourRange])
            minute = Int(text[minuteRange]) ?? 0
        }

        guard let hour, (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        let day = dates.first ?? range.start
        let start = day.setting(hour: hour, minute: minute, calendar: calendar)
        let end = start.addingTimeInterval(2 * 60 * 60)
        return DateInterval(start: start, end: end)
    }
'''
    text = text[:start] + replacement + text[end:]

PATH.write_text(text, encoding="utf-8")
print("Casual Japanese date/time parsing hardened.")
