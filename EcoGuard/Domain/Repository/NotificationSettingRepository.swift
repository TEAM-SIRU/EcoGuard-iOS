/// 기기에 저장하는 알림 설정.
protocol NotificationSettingRepository {
    /// 청소 알림을 켰는지. 저장한 적이 없으면 켠 상태다.
    func isCleaningReminderOn() -> Bool
    func setCleaningReminderOn(_ isOn: Bool)
    /// 마지막으로 홈에서 받은 배정 구역·시각. 마이페이지에서 알림을 켤 때 이 값으로 예약한다. 미배정·로그아웃이면 nil.
    func cleaningReminderSchedule() -> CleaningReminderSchedule?
    func setCleaningReminderSchedule(_ schedule: CleaningReminderSchedule?)
}
