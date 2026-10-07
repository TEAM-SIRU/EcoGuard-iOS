/// 배정 구역·시각이 바뀌면(앱 시작, 홈 갱신, 로그아웃) 청소 알림을 다시 맞춘다.
struct SyncCleaningReminderUseCase {
    private let notificationSettingRepository: NotificationSettingRepository
    private let cleaningReminderScheduler: CleaningReminderScheduler

    init(notificationSettingRepository: NotificationSettingRepository, cleaningReminderScheduler: CleaningReminderScheduler) {
        self.notificationSettingRepository = notificationSettingRepository
        self.cleaningReminderScheduler = cleaningReminderScheduler
    }

    /// `schedule`이 nil이면(미배정·활동 제외·로그아웃·탈퇴) 해제한다.
    /// 알림을 켰고 권한이 있을 때만 예약한다. 권한은 묻지 않는다(첫 진입 `RequestInitialCleaningReminderUseCase`, 마이페이지 스위치에서 묻는다).
    func execute(schedule: CleaningReminderSchedule?) async {
        notificationSettingRepository.setCleaningReminderSchedule(schedule)
        guard let schedule, notificationSettingRepository.isCleaningReminderOn() else {
            cleaningReminderScheduler.cancel()
            return
        }
        guard await cleaningReminderScheduler.isAuthorized() else {
            cleaningReminderScheduler.cancel()
            return
        }
        await cleaningReminderScheduler.schedule(schedule)
    }
}
