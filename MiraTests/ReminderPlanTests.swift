import XCTest
@testable import Mira

final class ReminderPlanTests: XCTestCase {
    func testOnlySentActiveAdjustmentsGetReminders() {
        for status in [AdjustmentStatus.draft, .confirmed, .cancelled] {
            XCTAssertNil(ReminderPlan.adjustment(id: UUID(), title: "相談", status: status, deadline: TestFixtures.date(day: 12), catVoice: false))
        }
        XCTAssertNotNil(ReminderPlan.adjustment(id: UUID(), title: "相談", status: .waiting, deadline: TestFixtures.date(day: 12), catVoice: false))
        XCTAssertNil(ReminderPlan.adjustment(id: UUID(), title: "相談", status: .waiting, deadline: nil, catVoice: false))
    }

    func testInvitationReminderEndsWhenDecisionIsMade() {
        for status in [InvitationStatus.accepted, .adjustment, .declined, .archived] {
            XCTAssertNil(ReminderPlan.invitation(id: UUID(), title: "誘い", status: status, deadline: TestFixtures.date(day: 12), catVoice: false))
        }
        XCTAssertNotNil(ReminderPlan.invitation(id: UUID(), title: "誘い", status: .considering, deadline: TestFixtures.date(day: 12), catVoice: false))
    }

    func testPastDeadlineNeverBecomesAnAlarmOneMinuteFromNow() {
        let deadline = TestFixtures.date(day: 12, hour: 18)
        let plan = ReminderPlan(destination: ReminderDestination(kind: .adjustment, id: UUID()), title: "相談", deadline: deadline, catVoice: false)
        XCTAssertNil(plan.triggerDate(now: TestFixtures.date(day: 13)))
        XCTAssertNil(plan.triggerDate(now: deadline))
        XCTAssertEqual(plan.triggerDate(now: TestFixtures.date(day: 10)), deadline.addingTimeInterval(-86_400))
        XCTAssertEqual(plan.triggerDate(now: TestFixtures.date(day: 12)), deadline)
    }

    func testNotificationDestinationRoundTripsBothKinds() {
        for kind in [ReminderDestination.Kind.adjustment, .invitation] {
            let value = ReminderDestination(kind: kind, id: UUID())
            XCTAssertEqual(ReminderDestination(rawValue: value.rawValue), value)
        }
        XCTAssertNil(ReminderDestination(rawValue: "adjustment:invalid"))
        XCTAssertNil(ReminderDestination(rawValue: "unknown:00000000-0000-0000-0000-000000000000"))
    }
}
