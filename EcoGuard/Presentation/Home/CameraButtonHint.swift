import SwiftUI

/// 가운데 카메라 버튼의 VoiceOver 힌트(#92). 꺼져 있으면 언제 쓸 수 있는지, 켜져 있어도 지금 인증할 수 없으면 그 까닭을 알린다.
/// 인증할 수 있을 때는 힌트를 두지 않는다. Figma에 없는 접근성 문구라 기획 확인 대상이다.
enum CameraButtonHint: Equatable {
    /// 홈을 불러오는 중이라 아직 꺼져 있다.
    case loading
    /// 홈 조회에 실패해 꺼져 있다.
    case failed
    /// 모집 중·미선발·모집 없음. 환경지킴이가 아니다.
    case notGuardian
    case awaitingAssignment
    case excluded
    case vacation
    /// 켜져 있지만 인증 시간 전이다. 누르면 인증 시간 안내가 열린다.
    case notOpenYet
    /// 켜져 있지만 오늘 이미 보냈다. 누르면 제출한 인증 안내가 열린다.
    case alreadySubmitted

    init?(state: HomeViewModel.State) {
        switch state {
        case .loading:
            self = .loading
        case .failed:
            self = .failed
        case .loaded(let summary):
            switch summary.status {
            case .recruiting, .notSelected, .notRecruiting:
                self = .notGuardian
            case .awaitingAssignment:
                self = .awaitingAssignment
            case .excluded:
                self = .excluded
            case .active(let cleaning):
                switch cleaning.today.verification {
                case .open:
                    return nil
                case .notOpenYet:
                    self = .notOpenYet
                case .vacation:
                    self = .vacation
                case .aiReviewing, .teacherReviewing, .approved, .rejected:
                    self = .alreadySubmitted
                }
            }
        }
    }

    var text: LocalizedStringKey {
        switch self {
        case .loading: "홈을 불러온 뒤 쓸 수 있어요"
        case .failed: "홈을 다시 불러오면 쓸 수 있어요"
        case .notGuardian: "환경지킴이로 활동 중일 때 쓸 수 있어요"
        case .awaitingAssignment: "청소 구역을 배정받으면 쓸 수 있어요"
        case .excluded: "활동에서 제외되어 쓸 수 없어요"
        // 인증 화면의 방학 안내(`VerificationClosedCopy.vacationMessage`)와 같은 문구.
        case .vacation: "방학 기간에는 청소 인증을 하지 않아요"
        case .notOpenYet: "지금은 인증 시간이 아니에요"
        case .alreadySubmitted: "오늘은 이미 인증했어요"
        }
    }
}
