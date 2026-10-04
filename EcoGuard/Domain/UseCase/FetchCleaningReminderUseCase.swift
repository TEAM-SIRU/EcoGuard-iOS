struct FetchCleaningReminderUseCase {
    private let notificationSettingRepository: NotificationSettingRepository

    init(notificationSettingRepository: NotificationSettingRepository) {
        self.notificationSettingRepository = notificationSettingRepository
    }

    func execute() -> Bool {
        notificationSettingRepository.isCleaningReminderOn()
    }
}
