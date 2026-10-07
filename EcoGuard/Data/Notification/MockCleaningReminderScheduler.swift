/// 서버 주소와 상관없이 실제 알림을 쓰지 않는 곳(Preview, 화면 모음, 단위 테스트)에서 쓴다. 권한은 허용된 것으로 보고 아무것도 예약하지 않는다.
final class MockCleaningReminderScheduler: CleaningReminderScheduler {
    func isAuthorized() async -> Bool { true }
    func requestAuthorization() async -> Bool { true }
    func schedule(_ schedule: CleaningReminderSchedule) async {}
    func cancel() {}
}
