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

        repository.setCleaningReminderOn(false)

        #expect(!NotificationSettingRepositoryImpl(defaults: defaults).isCleaningReminderOn())
    }
}
