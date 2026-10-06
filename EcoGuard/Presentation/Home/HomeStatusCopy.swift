import SwiftUI

/// 서버 연동으로 생긴 홈 상태 카드 문구. Figma에 없는 임시 문구라 기획 확인 대상이다(한 곳에 모아 둔다).
enum HomeStatusCopy {
    enum ApplicationPending {
        static let tag: LocalizedStringKey = "확정 대기"
        static let title: LocalizedStringKey = "신청을 받았어요"
        static let message: LocalizedStringKey = "선생님 확정을 기다리고 있어요"
    }

    enum NotSelected {
        static let tag: LocalizedStringKey = "모집 결과"
        static let title: LocalizedStringKey = "이번 모집에서 선발되지 않았어요"
        static let message: LocalizedStringKey = "다음 모집이 열리면 다시 신청할 수 있어요"
    }

    enum NotRecruiting {
        static let tag: LocalizedStringKey = "모집 없음"
        static let title: LocalizedStringKey = "지금은 모집 기간이 아니에요"
        static let message: LocalizedStringKey = "모집이 시작되면 홈에서 바로 볼 수 있어요"
    }
}
