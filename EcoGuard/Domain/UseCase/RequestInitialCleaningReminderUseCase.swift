/// 청소 알림을 정한 적 없는 학생이 로그인 후 메인에 처음 들어오면 알림 권한을 한 번 묻는다(기본 켜짐).
/// 허용하면 켜짐으로 저장하고 배정 구역이 있으면 예약한다. 거부하면 꺼짐으로 저장해 다시 묻지 않는다.
struct RequestInitialCleaningReminderUseCase {
    private let notificationSettingRepository: NotificationSettingRepository
    private let cleaningReminderScheduler: CleaningReminderScheduler

    init(notificationSettingRepository: NotificationSettingRepository, cleaningReminderScheduler: CleaningReminderScheduler) {
        self.notificationSettingRepository = notificationSettingRepository
        self.cleaningReminderScheduler = cleaningReminderScheduler
    }

    func execute() async {
        guard !notificationSettingRepository.hasDecidedCleaningReminder() else { return }
        let isGranted = await cleaningReminderScheduler.requestAuthorization()
        notificationSettingRepository.setCleaningReminderOn(isGranted)
        guard isGranted, let schedule = notificationSettingRepository.cleaningReminderSchedule() else { return }
        await cleaningReminderScheduler.schedule(schedule)
    }
}
