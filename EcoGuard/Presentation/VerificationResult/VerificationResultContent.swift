import SwiftUI

/// 검수 상태별 화면 구성·문구.
/// - 승인·선생님 확인 중: Figma `08 인증 결과 · 승인` (239:213) · `선생님 확인 중` (255:446)
/// - 반려: Figma `08 인증 결과 · 반려` (239:240)
/// - 검수 중: Figma `08 인증 상세 · 기록에서 열기` (317:430). 결과가 나오기 전이라 상세 형태로 보여 준다.
struct VerificationResultContent: Equatable {
    enum Layout: Equatable {
        /// 가운데 아이콘·제목 + 사진 + 정보 표 + `확인`.
        case summary(hero: Hero)
        /// 아이콘·제목 + AI 검수 결과 + 사진 + 이의신청.
        case rejected(reason: VerificationResult.RejectionReason?)
        /// 왼쪽 정렬 날짜 제목 + 큰 사진 + 정보 표.
        case detail
    }

    enum Hero: Equatable {
        case check
        case clock
    }

    struct Row: Equatable {
        enum Tone: Equatable {
            case normal
            case earned
            case pending
        }

        let label: String
        let value: String
        var tone: Tone = .normal
    }

    let layout: Layout
    let title: String
    let message: String
    let rows: [Row]

    init(result: VerificationResult, now: Date) {
        let submittedAt = VerificationResultFormatter.submittedAt(result.submittedAt, now: now)
        let areaRow = Row(label: "담당 구역", value: result.area)
        switch result.status {
        case .approved:
            layout = .summary(hero: .check)
            title = "청소 인증이 완료됐어요"
            message = "수고했어요. 활동 시간에 \(result.earnedMinutes)분을 더했어요"
            rows = [
                areaRow,
                Row(label: "제출 시각", value: submittedAt),
                Row(label: "적립", value: "+\(result.earnedMinutes)분", tone: .earned)
            ]
        case .manualReview:
            layout = .summary(hero: .clock)
            title = "선생님이 직접 확인할게요"
            message = "AI가 판단하기 어려운 사진이라 선생님께 보냈어요"
            rows = [
                areaRow,
                Row(label: "제출 시각", value: submittedAt),
                Row(label: "상태", value: "선생님 확인 중", tone: .pending)
            ]
        case .rejected:
            layout = .rejected(reason: result.rejectionReason)
            title = "인증이 반려됐어요"
            message = "\(result.area) · \(submittedAt) 제출"
            rows = []
        case .processing:
            layout = .detail
            title = "\(VerificationResultFormatter.day(result.submittedAt)) 인증"
            message = "AI가 사진을 확인하고 있어요"
            rows = [
                Row(label: "상태", value: "검수 중", tone: .pending),
                areaRow,
                Row(label: "제출 시각", value: HomeFormatter.recordDate(result.submittedAt))
            ]
        }
    }
}

extension VerificationResultContent.Row.Tone {
    var color: Color {
        switch self {
        case .normal: .ecoTextPrimary
        case .earned: .ecoPrimaryText
        case .pending: .ecoPending
        }
    }
}
