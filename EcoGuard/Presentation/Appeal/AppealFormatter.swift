import Foundation

/// 이의신청 화면 문구. 날짜는 학교 기준 KST(`HomeFormatter`)로 고정한다.
enum AppealFormatter {
    /// "9월 22일(화) 인증"
    static func verificationTitle(_ appeal: Appeal) -> String {
        "\(VerificationResultFormatter.day(appeal.verifiedAt)) 인증"
    }

    /// 내역 행 보조 문구. "2차 · 9월 29일(화) 12:20 보냄", 승인이면 " · +10분"을 붙인다.
    static func historySubtitle(_ appeal: Appeal) -> String {
        let sent = "\(appeal.round)차 · \(HomeFormatter.recordDate(appeal.submittedAt)) 보냄"
        return appeal.status == .approved ? "\(sent) · \(earned(appeal))" : sent
    }

    /// 결과 화면 설명. "9월 22일(화) 인증 · 1차 이의신청"
    static func resultSubtitle(_ appeal: Appeal) -> String {
        "\(verificationTitle(appeal)) · \(appeal.round)차 이의신청"
    }

    /// "+10분"
    static func earned(_ appeal: Appeal) -> String {
        "+\(appeal.earnedMinutes)분"
    }
}
