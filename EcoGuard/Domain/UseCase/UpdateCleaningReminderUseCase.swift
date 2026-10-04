struct UpdateCleaningReminderUseCase {
    private let notificationSettingRepository: NotificationSettingRepository

    init(notificationSettingRepository: NotificationSettingRepository) {
        self.notificationSettingRepository = notificationSettingRepository
    }

    // TODO: 알림 종류별 시점이 정해지면 여기서 기기 알림 예약·해제도 한다.
    func execute(isOn: Bool) {
        notificationSettingRepository.setCleaningReminderOn(isOn)
    }
}
