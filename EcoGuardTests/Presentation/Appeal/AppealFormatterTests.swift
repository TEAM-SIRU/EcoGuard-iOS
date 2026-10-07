import Foundation
import Testing
@testable import EcoGuard

@MainActor
struct AppealFormatterTests {
    private typealias Fixture = MockAppealRepository.Fixture

    @Test func serverStatusValuesMapToCases() {
        #expect(Appeal.Status(rawValue: "REVIEWING") == .reviewing)
        #expect(Appeal.Status(rawValue: "APPROVED") == .approved)
        #expect(Appeal.Status(rawValue: "REJECTED") == .rejected)
    }

    /// Figma `09-3 이의신청 내역` (317:1018) 행 문구.
    @Test func historyRowsMatchFigma() {
        #expect(AppealFormatter.verificationTitle(Fixture.reviewing) == "9월 22일(화) 인증")
        #expect(AppealFormatter.historySubtitle(Fixture.reviewing) == "2차 · 9월 29일(화) 12:20 보냄")
        #expect(AppealFormatter.historySubtitle(Fixture.rejected) == "1차 · 9월 22일(화) 13:02 보냄")
        #expect(AppealFormatter.verificationTitle(Fixture.approved) == "9월 21일(월) 인증")
        #expect(AppealFormatter.historySubtitle(Fixture.approved) == "1차 · 9월 21일(월) 12:40 보냄 · +10분")
    }

    /// Figma 결과 반려 (317:1206) · 승인 (514:217) · 적립 (514:223).
    @Test func resultTextMatchesFigma() {
        #expect(AppealFormatter.resultSubtitle(Fixture.rejected) == "9월 22일(화) 인증 · 1차 이의신청")
        #expect(AppealFormatter.resultSubtitle(Fixture.approved) == "9월 21일(월) 인증 · 1차 이의신청")
        #expect(AppealFormatter.earned(Fixture.approved) == "+10분")
        #expect(AppealFormatter.approvedMessage(Fixture.approved) == "9월 21일(월) 인증 · 1차 이의신청\n\n선생님이 청소한 내용을 확인했어요.\n활동 기록에 10분이 추가됐어요.")
    }

    /// 승인됐지만 대상 인증이 이미 승인돼 적립하지 않았으면 분을 보이지 않는다.
    @Test func approvedWithoutMinutesShowsNoEarnedText() {
        let appeal = Fixture.approvedWithoutMinutes

        #expect(AppealFormatter.earned(appeal) == nil)
        #expect(AppealFormatter.historySubtitle(appeal) == "1차 · 9월 21일(월) 12:40 보냄")
        #expect(AppealFormatter.approvedMessage(appeal) == "9월 21일(월) 인증 · 1차 이의신청\n\n선생님이 청소한 내용을 확인했어요.")
    }

    @Test func rejectedShowsNoEarnedText() {
        #expect(AppealFormatter.earned(Fixture.rejected) == nil)
        #expect(AppealFormatter.earned(Fixture.reviewing) == nil)
    }

    @Test func retryTargetUsesTeacherReplyAsReason() {
        let target = Fixture.rejected.retryTarget

        #expect(target.verificationID == Fixture.rejectedVerificationID)
        #expect(target.verifiedAt == Fixture.rejectedVerifiedAt)
        #expect(target.rejectionReason == "사진에 구역 표지판이 보이지 않아요")
    }

    @Test func targetFromRejectedVerification() {
        let result = MockVerificationResultRepository.Fixture.result(status: .rejected)
        let target = AppealTarget(result: result)

        #expect(target.verificationID == result.id)
        #expect(target.verifiedAt == result.submittedAt)
        #expect(target.rejectionReason == "사진에 청소 구역이 잘 보이지 않아요")
    }
}
