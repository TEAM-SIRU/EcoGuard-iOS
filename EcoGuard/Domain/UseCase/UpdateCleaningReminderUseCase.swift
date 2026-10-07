struct UpdateCleaningReminderUseCase {
    private let notificationSettingRepository: NotificationSettingRepository
    private let cleaningReminderScheduler: CleaningReminderScheduler

    init(notificationSettingRepository: NotificationSettingRepository, cleaningReminderScheduler: CleaningReminderScheduler) {
        self.notificationSettingRepository = notificationSettingRepository
        self.cleaningReminderScheduler = cleaningReminderScheduler
    }

    /// 켜면 알림 권한을 묻고, 허용되면 저장한 배정 구역·시각으로 예약한다. 거부되면 끈 채로 둔다.
    /// 끄면 예약을 해제한다. 바뀐 뒤 켜져 있는지 돌려준다.
    func execute(isOn: Bool) async -> Bool {
        guard isOn else {
            notificationSettingRepository.setCleaningReminderOn(false)
            cleaningReminderScheduler.cancel()
            return false
        }
        guard await cleaningReminderScheduler.requestAuthorization() else {
            notificationSettingRepository.setCleaningReminderOn(false)
            return false
        }
        notificationSettingRepository.setCleaningReminderOn(true)
        if let schedule = notificationSettingRepository.cleaningReminderSchedule() {
            await cleaningReminderScheduler.schedule(schedule)
        }
        return true
    }
}
