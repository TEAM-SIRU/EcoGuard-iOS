import Foundation
import Testing
@testable import EcoGuard

struct NotificationSettingRepositoryImplTests {
    @Test func cleaningReminderIsOnUntilSavedAndKeepsSavedValue() throws {
        let suiteName = "NotificationSettingRepositoryImplTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let repository = NotificationSettingRepositoryImpl(defaults: defaults)

        #expect(repository.isCleaningReminderOn())
        #expect(!repository.hasDecidedCleaningReminder())

        repository.setCleaningReminderOn(false)
        #expect(repository.hasDecidedCleaningReminder())

        #expect(!NotificationSettingRepositoryImpl(defaults: defaults).isCleaningReminderOn())
    }

    @Test func cleaningReminderScheduleIsSavedAndCleared() throws {
        let suiteName = "NotificationSettingRepositoryImplTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let repository = NotificationSettingRepositoryImpl(defaults: defaults)
        let schedule = CleaningReminderSchedule(areaName: "본관 2층 복도 A", startMinute: 440)

        #expect(repository.cleaningReminderSchedule() == nil)

        repository.setCleaningReminderSchedule(schedule)
        #expect(NotificationSettingRepositoryImpl(defaults: defaults).cleaningReminderSchedule() == schedule)

        repository.setCleaningReminderSchedule(nil)
        #expect(repository.cleaningReminderSchedule() == nil)
    }
}
