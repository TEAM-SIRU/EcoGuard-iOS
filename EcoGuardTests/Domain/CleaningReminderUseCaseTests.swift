import Foundation
import Testing
@testable import EcoGuard

@MainActor
struct CleaningReminderUseCaseTests {
    /// 권한 상태와 예약을 기록한다.
    private final class SpyScheduler: CleaningReminderScheduler {
        var authorized: Bool
        /// 권한을 물었을 때 사용자가 고를 답.
        var grants: Bool
        private(set) var requestAuthorizationCount = 0
        private(set) var scheduled: CleaningReminderSchedule?
        private(set) var scheduleCount = 0
        private(set) var cancelCount = 0

        init(authorized: Bool = true, grants: Bool = true) {
            self.authorized = authorized
            self.grants = grants
        }

        func isAuthorized() async -> Bool { authorized }

        func requestAuthorization() async -> Bool {
            requestAuthorizationCount += 1
            authorized = authorized || grants
            return authorized
        }

        func schedule(_ schedule: CleaningReminderSchedule) async {
            scheduleCount += 1
            scheduled = schedule
        }

        func cancel() {
            cancelCount += 1
            scheduled = nil
        }
    }

    private final class InMemorySettings: NotificationSettingRepository {
        var isOn: Bool?
        var schedule: CleaningReminderSchedule?

        func isCleaningReminderOn() -> Bool { isOn ?? true }
        func setCleaningReminderOn(_ isOn: Bool) { self.isOn = isOn }
        func hasDecidedCleaningReminder() -> Bool { isOn != nil }
        func cleaningReminderSchedule() -> CleaningReminderSchedule? { schedule }
        func setCleaningReminderSchedule(_ schedule: CleaningReminderSchedule?) { self.schedule = schedule }
    }

    private let area = CleaningReminderSchedule(areaName: "본관 2층 복도 A", startMinute: 440)

    // MARK: - 켜기·끄기

    @Test func turningOnWithPermissionSchedulesSavedArea() async {
        let settings = InMemorySettings()
        settings.isOn = false
        settings.schedule = area
        let scheduler = SpyScheduler(authorized: false, grants: true)

        let isOn = await UpdateCleaningReminderUseCase(notificationSettingRepository: settings, cleaningReminderScheduler: scheduler)
            .execute(isOn: true)

        #expect(isOn)
        #expect(settings.isOn == true)
        #expect(scheduler.requestAuthorizationCount == 1)
        #expect(scheduler.scheduled == area)
    }

    @Test func turningOnWithoutAssignmentSchedulesNothing() async {
        let settings = InMemorySettings()
        settings.isOn = false
        let scheduler = SpyScheduler()

        let isOn = await UpdateCleaningReminderUseCase(notificationSettingRepository: settings, cleaningReminderScheduler: scheduler)
            .execute(isOn: true)

        #expect(isOn)
        #expect(scheduler.scheduleCount == 0)
    }

    @Test func turningOnWhenDeniedStaysOff() async {
        let settings = InMemorySettings()
        settings.isOn = false
        settings.schedule = area
        let scheduler = SpyScheduler(authorized: false, grants: false)

        let isOn = await UpdateCleaningReminderUseCase(notificationSettingRepository: settings, cleaningReminderScheduler: scheduler)
            .execute(isOn: true)

        #expect(!isOn)
        #expect(settings.isOn == false)
        #expect(scheduler.scheduleCount == 0)
    }

    @Test func turningOffCancels() async {
        let settings = InMemorySettings()
        settings.schedule = area
        let scheduler = SpyScheduler()
        let update = UpdateCleaningReminderUseCase(notificationSettingRepository: settings, cleaningReminderScheduler: scheduler)
        _ = await update.execute(isOn: true)

        let isOn = await update.execute(isOn: false)

        #expect(!isOn)
        #expect(settings.isOn == false)
        #expect(scheduler.cancelCount == 1)
        #expect(scheduler.scheduled == nil)
    }

    // MARK: - 배정 구역·시각 맞추기

    @Test func activeStatusSchedulesAreaAtStartTime() async throws {
        let settings = InMemorySettings()
        let scheduler = SpyScheduler()
        let status = try #require(MockHomeRepository.Fixture.summary(for: .notSubmitted, now: .now)).status

        await SyncCleaningReminderUseCase(notificationSettingRepository: settings, cleaningReminderScheduler: scheduler)
            .execute(schedule: status.cleaningReminderSchedule)

        let expected = CleaningReminderSchedule(
            areaName: MockHomeRepository.Fixture.area,
            startMinute: MockHomeRepository.Fixture.window.startMinute
        )
        #expect(scheduler.scheduled == expected)
        #expect(settings.schedule == expected)
    }

    @Test(arguments: [
        HomeStatus.awaitingAssignment,
        .notRecruiting,
        .notSelected,
        .excluded(reason: "본인 요청으로 활동을 중단했어요.")
    ])
    func unassignedOrExcludedCancels(status: HomeStatus) async {
        let settings = InMemorySettings()
        let scheduler = SpyScheduler()
        let sync = SyncCleaningReminderUseCase(notificationSettingRepository: settings, cleaningReminderScheduler: scheduler)
        await sync.execute(schedule: area)

        await sync.execute(schedule: status.cleaningReminderSchedule)

        #expect(scheduler.cancelCount == 1)
        #expect(scheduler.scheduled == nil)
        #expect(settings.schedule == nil)
    }

    @Test func changedTimeReschedules() async {
        let settings = InMemorySettings()
        let scheduler = SpyScheduler()
        let sync = SyncCleaningReminderUseCase(notificationSettingRepository: settings, cleaningReminderScheduler: scheduler)
        let later = CleaningReminderSchedule(areaName: area.areaName, startMinute: 480)

        await sync.execute(schedule: area)
        await sync.execute(schedule: later)

        #expect(scheduler.scheduled == later)
        #expect(settings.schedule == later)
    }

    /// 앱 셸은 로그아웃(탈퇴·세션 만료 포함)하면 nil을 넘긴다.
    @Test func logoutCancelsAndForgetsArea() async {
        let settings = InMemorySettings()
        let scheduler = SpyScheduler()
        let sync = SyncCleaningReminderUseCase(notificationSettingRepository: settings, cleaningReminderScheduler: scheduler)
        await sync.execute(schedule: area)

        await sync.execute(schedule: nil)

        #expect(scheduler.scheduled == nil)
        #expect(settings.schedule == nil)
        #expect(settings.isCleaningReminderOn())
    }

    @Test func turnedOffSyncOnlyKeepsArea() async {
        let settings = InMemorySettings()
        settings.isOn = false
        let scheduler = SpyScheduler()

        await SyncCleaningReminderUseCase(notificationSettingRepository: settings, cleaningReminderScheduler: scheduler)
            .execute(schedule: area)

        #expect(scheduler.scheduleCount == 0)
        #expect(settings.schedule == area)
    }

    /// 홈 갱신에서는 권한을 묻지 않고, 정하지 않은 사용자의 설정도 저장하지 않는다(첫 진입 요청이 남는다).
    @Test func syncWithoutPermissionNeitherAsksNorSaves() async {
        let settings = InMemorySettings()
        let scheduler = SpyScheduler(authorized: false)

        await SyncCleaningReminderUseCase(notificationSettingRepository: settings, cleaningReminderScheduler: scheduler)
            .execute(schedule: area)

        #expect(scheduler.requestAuthorizationCount == 0)
        #expect(scheduler.scheduleCount == 0)
        #expect(settings.isOn == nil)
    }

    @Test func fetchShowsOffWhenPermissionRevokedWithoutSaving() async {
        let settings = InMemorySettings()
        settings.isOn = true
        let scheduler = SpyScheduler(authorized: false)
        let fetch = FetchCleaningReminderUseCase(notificationSettingRepository: settings, cleaningReminderScheduler: scheduler)

        #expect(fetch.execute())
        #expect(!(await fetch.executeCheckingAuthorization()))
        #expect(settings.isOn == true)
    }

    // MARK: - 첫 진입 권한 요청

    @Test func firstEntryAllowedTurnsOnAndSchedulesAssignedArea() async {
        let settings = InMemorySettings()
        settings.schedule = area
        let scheduler = SpyScheduler(authorized: false, grants: true)

        await RequestInitialCleaningReminderUseCase(notificationSettingRepository: settings, cleaningReminderScheduler: scheduler)
            .execute()

        #expect(scheduler.requestAuthorizationCount == 1)
        #expect(settings.isOn == true)
        #expect(scheduler.scheduled == area)
    }

    @Test func firstEntryAllowedWithoutAssignmentOnlyTurnsOn() async {
        let settings = InMemorySettings()
        let scheduler = SpyScheduler(authorized: false, grants: true)

        await RequestInitialCleaningReminderUseCase(notificationSettingRepository: settings, cleaningReminderScheduler: scheduler)
            .execute()

        #expect(settings.isOn == true)
        #expect(scheduler.scheduleCount == 0)
    }

    @Test func firstEntryDeniedTurnsOffAndIsNotAskedAgain() async {
        let settings = InMemorySettings()
        settings.schedule = area
        let scheduler = SpyScheduler(authorized: false, grants: false)
        let request = RequestInitialCleaningReminderUseCase(notificationSettingRepository: settings, cleaningReminderScheduler: scheduler)

        await request.execute()
        await request.execute()

        #expect(scheduler.requestAuthorizationCount == 1)
        #expect(settings.isOn == false)
        #expect(scheduler.scheduleCount == 0)
    }

    @Test(arguments: [true, false])
    func alreadyDecidedUserIsNotAsked(isOn: Bool) async {
        let settings = InMemorySettings()
        settings.isOn = isOn
        settings.schedule = area
        let scheduler = SpyScheduler(authorized: false, grants: true)

        await RequestInitialCleaningReminderUseCase(notificationSettingRepository: settings, cleaningReminderScheduler: scheduler)
            .execute()

        #expect(scheduler.requestAuthorizationCount == 0)
        #expect(settings.isOn == isOn)
        #expect(scheduler.scheduleCount == 0)
    }
}
