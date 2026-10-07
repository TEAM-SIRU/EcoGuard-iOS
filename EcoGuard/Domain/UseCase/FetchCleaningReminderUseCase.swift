struct FetchCleaningReminderUseCase {
    private let notificationSettingRepository: NotificationSettingRepository
    private let cleaningReminderScheduler: CleaningReminderScheduler

    init(notificationSettingRepository: NotificationSettingRepository, cleaningReminderScheduler: CleaningReminderScheduler) {
        self.notificationSettingRepository = notificationSettingRepository
        self.cleaningReminderScheduler = cleaningReminderScheduler
    }

    /// 저장된 값. 화면을 처음 그릴 때 쓴다.
    func execute() -> Bool {
        notificationSettingRepository.isCleaningReminderOn()
    }

    /// 저장된 값과 알림 권한을 같이 본다. 켜 두었어도 권한이 없으면(아직 묻지 않음, 설정 앱에서 끔) 끈 것으로 보여 준다.
    /// 저장된 값은 바꾸지 않는다. 설정 앱에서 다시 허용하면 그대로 켜진다.
    func executeCheckingAuthorization() async -> Bool {
        guard notificationSettingRepository.isCleaningReminderOn() else { return false }
        return await cleaningReminderScheduler.isAuthorized()
    }
}
