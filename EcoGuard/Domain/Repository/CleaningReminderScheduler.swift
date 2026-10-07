/// 기기 청소 알림 예약. 실제 알림 센터는 Data 계층(`CleaningReminderSchedulerImpl`)이 감싼다.
protocol CleaningReminderScheduler {
    /// 알림 권한이 허용돼 있는지.
    func isAuthorized() async -> Bool
    /// 알림 권한을 묻는다. 이미 정했으면 다시 묻지 않고 지금 상태를 돌려준다.
    func requestAuthorization() async -> Bool
    /// 평일(월~금) `schedule.startMinute`에 반복 알림을 건다. 고정 식별자라 이전 예약을 덮어 중복되지 않는다.
    func schedule(_ schedule: CleaningReminderSchedule) async
    /// 걸어 둔 청소 알림을 모두 해제한다.
    func cancel()
}
