import Foundation

extension AvailabilityRuleDraft {
    static var allWeekdays: [AvailabilityRuleDraft] {
        standardWeekdays.map { draft in
            var copy = draft
            copy.isEnabled = false
            return copy
        }
    }
}
