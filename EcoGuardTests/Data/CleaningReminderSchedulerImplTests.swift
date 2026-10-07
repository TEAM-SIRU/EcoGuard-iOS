import Testing
import UserNotifications
@testable import EcoGuard

@MainActor
struct CleaningReminderSchedulerImplTests {
    /// 예약을 식별자별로 들고 있는 알림 센터. 같은 식별자로 다시 넣으면 덮는다(실제 센터와 같다).
    private final class StubNotificationCenter: UserNotificationCenter {
        var status: UNAuthorizationStatus
        /// 권한을 물었을 때 사용자가 고를 답.
        var grants: Bool
        private(set) var requestAuthorizationCount = 0
        private(set) var addCount = 0
        private(set) var pending: [String: UNNotificationRequest] = [:]

        init(status: UNAuthorizationStatus = .authorized, grants: Bool = true) {
            self.status = status
            self.grants = grants
        }

        func authorizationStatus() async -> UNAuthorizationStatus { status }

        func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
            requestAuthorizationCount += 1
            if status == .notDetermined { status = grants ? .authorized : .denied }
            return status == .authorized
        }

        func add(_ request: UNNotificationRequest) async throws {
            addCount += 1
            pending[request.identifier] = request
        }

        func pendingNotificationRequests() async -> [UNNotificationRequest] {
            Array(pending.values)
        }

        func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
            for identifier in identifiers { pending[identifier] = nil }
        }
    }

    private let schedule = CleaningReminderSchedule(areaName: "본관 2층 복도 A", startMinute: 440)

    @Test func scheduleAddsWeekdayRepeatsAtStartTime() async throws {
        let center = StubNotificationCenter()
        let scheduler = CleaningReminderSchedulerImpl(center: center)

        await scheduler.schedule(schedule)

        #expect(center.pending.keys.sorted() == CleaningReminderSchedulerImpl.identifiers.sorted())
        let triggers = try center.pending.values.map { try #require($0.trigger as? UNCalendarNotificationTrigger) }
        #expect(triggers.allSatisfy { $0.repeats })
        #expect(triggers.compactMap(\.dateComponents.weekday).sorted() == [2, 3, 4, 5, 6])
        #expect(triggers.allSatisfy { $0.dateComponents.hour == 7 && $0.dateComponents.minute == 20 })
        #expect(triggers.allSatisfy { $0.dateComponents.timeZone == ServerDate.timeZone })
        let content = try #require(center.pending.values.first?.content)
        #expect(content.title == "청소 인증할 시간이에요")
        #expect(content.body == "본관 2층 복도 A 청소 후 사진으로 인증해 주세요")
    }

    @Test func sameScheduleIsNotAddedAgain() async {
        let center = StubNotificationCenter()
        let scheduler = CleaningReminderSchedulerImpl(center: center)

        await scheduler.schedule(schedule)
        await scheduler.schedule(schedule)

        #expect(center.addCount == 5)
    }

    @Test func changedTimeReplacesScheduleWithoutDuplicates() async throws {
        let center = StubNotificationCenter()
        let scheduler = CleaningReminderSchedulerImpl(center: center)

        await scheduler.schedule(schedule)
        await scheduler.schedule(CleaningReminderSchedule(areaName: "별관 1층 계단", startMinute: 480))

        #expect(center.pending.count == 5)
        let triggers = try center.pending.values.map { try #require($0.trigger as? UNCalendarNotificationTrigger) }
        #expect(triggers.allSatisfy { $0.dateComponents.hour == 8 && $0.dateComponents.minute == 0 })
        #expect(center.pending.values.allSatisfy { $0.content.body == "별관 1층 계단 청소 후 사진으로 인증해 주세요" })
    }

    @Test func cancelRemovesOnlyCleaningReminders() async throws {
        let center = StubNotificationCenter()
        let scheduler = CleaningReminderSchedulerImpl(center: center)
        let other = UNNotificationRequest(identifier: "other", content: UNNotificationContent(), trigger: nil)
        try await center.add(other)

        await scheduler.schedule(schedule)
        scheduler.cancel()

        #expect(Array(center.pending.keys) == ["other"])
    }

    @Test(arguments: [
        (UNAuthorizationStatus.authorized, true),
        (.provisional, true),
        (.ephemeral, true),
        (.denied, false),
        (.notDetermined, false)
    ] as [(UNAuthorizationStatus, Bool)])
    func isAuthorizedFollowsStatus(status: UNAuthorizationStatus, expected: Bool) async {
        let scheduler = CleaningReminderSchedulerImpl(center: StubNotificationCenter(status: status))

        #expect(await scheduler.isAuthorized() == expected)
    }

    @Test func requestAuthorizationReturnsUserChoice() async {
        let allowing = StubNotificationCenter(status: .notDetermined, grants: true)
        let denying = StubNotificationCenter(status: .notDetermined, grants: false)

        #expect(await CleaningReminderSchedulerImpl(center: allowing).requestAuthorization())
        #expect(!(await CleaningReminderSchedulerImpl(center: denying).requestAuthorization()))
    }
}
