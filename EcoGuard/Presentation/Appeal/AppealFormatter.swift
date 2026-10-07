import Foundation

/// 이의신청 화면 문구. 날짜는 학교 기준 KST(`HomeFormatter`)로 고정한다.
enum AppealFormatter {
    /// "9월 22일(화) 인증"
    static func verificationTitle(_ appeal: Appeal) -> String {
        "\(VerificationResultFormatter.day(appeal.verifiedAt)) 인증"
    }

    /// 내역 행 보조 문구. "2차 · 9월 29일(화) 12:20 보냄", 적립됐으면 " · +10분"을 붙인다.
    static func historySubtitle(_ appeal: Appeal) -> String {
        let sent = "\(appeal.round)차 · \(HomeFormatter.recordDate(appeal.submittedAt)) 보냄"
        return earned(appeal).map { "\(sent) · \($0)" } ?? sent
    }

    /// 결과 화면 설명. "9월 22일(화) 인증 · 1차 이의신청"
    static func resultSubtitle(_ appeal: Appeal) -> String {
        "\(verificationTitle(appeal)) · \(appeal.round)차 이의신청"
    }

    /// "+10분". 적립되지 않았으면 nil.
    static func earned(_ appeal: Appeal) -> String? {
        appeal.earnedMinutes.map { "+\($0)분" }
    }

    /// 승인 결과 본문. 적립되지 않았으면 적립 문구를 뺀다.
    static func approvedMessage(_ appeal: Appeal) -> String {
        let confirmed = "\(resultSubtitle(appeal))\n\n선생님이 청소한 내용을 확인했어요."
        return appeal.earnedMinutes.map { "\(confirmed)\n활동 기록에 \($0)분이 추가됐어요." } ?? confirmed
    }
}
