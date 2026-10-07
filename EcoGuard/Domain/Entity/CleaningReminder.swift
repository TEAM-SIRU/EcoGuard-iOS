/// 청소 알림을 걸 구역과 시각. 배정 구역의 인증 시작 시각(서버 청소 시간, 없으면 07:20)이다.
nonisolated struct CleaningReminderSchedule: Equatable {
    let areaName: String
    /// 하루 기준 분(0시 = 0). 예: 07:20 → 440.
    let startMinute: Int
}

extension HomeStatus {
    /// 이 상태에서 걸어 둘 청소 알림. 구역을 배정받아 활동 중일 때만 있고, 미배정·활동 제외 등은 nil(해제)이다.
    /// 방학은 서버가 기간을 주지 않아 따로 빼지 않는다.
    var cleaningReminderSchedule: CleaningReminderSchedule? {
        guard case .active(let cleaning) = self else { return nil }
        return CleaningReminderSchedule(areaName: cleaning.today.area, startMinute: cleaning.today.window.startMinute)
    }
}

/// 청소 알림 문구. 알림 시각(인증 시작 시각)과 본문은 확정, 제목·권한 거부 안내는 기획 확인 전 임시값이다.
enum CleaningReminderCopy {
    static let title = "청소 인증할 시간이에요"

    static func body(areaName: String) -> String {
        "\(areaName) 청소 후 사진으로 인증해 주세요"
    }

    /// 알림 권한을 거부해 스위치를 켤 수 없을 때 띄우는 안내.
    enum Denied {
        static let title = "알림이 꺼져 있어요"
        static let message = "설정 앱에서 EcoGuard 알림을 허용하면 청소 알림을 받을 수 있어요"
        static let cancel = "닫기"
        static let openSettings = "설정 열기"
    }
}
