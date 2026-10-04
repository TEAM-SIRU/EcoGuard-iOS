/// 기기에 저장하는 알림 설정.
protocol NotificationSettingRepository {
    /// 청소 알림을 켰는지. 저장한 적이 없으면 켠 상태다.
    func isCleaningReminderOn() -> Bool
    func setCleaningReminderOn(_ isOn: Bool)
}
