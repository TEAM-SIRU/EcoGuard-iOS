/// 서버 주소와 상관없이 실제 알림을 쓰지 않는 곳(Preview, 화면 모음, 단위 테스트)에서 쓴다. 아무것도 예약하지 않는다.
/// 권한은 기본으로 허용된 것으로 보고, `isAuthorized`를 false로 주면 거부된 것으로 본다(화면 모음의 권한 거부 안내).
final class MockCleaningReminderScheduler: CleaningReminderScheduler {
    private let authorized: Bool

    init(isAuthorized: Bool = true) {
        authorized = isAuthorized
    }

    func isAuthorized() async -> Bool { authorized }
    func requestAuthorization() async -> Bool { authorized }
    func schedule(_ schedule: CleaningReminderSchedule) async {}
    func cancel() {}
}
