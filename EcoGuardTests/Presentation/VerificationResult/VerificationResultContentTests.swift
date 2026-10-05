import Foundation
import Testing
@testable import EcoGuard

@MainActor
struct VerificationResultContentTests {
    private typealias Fixture = MockVerificationResultRepository.Fixture

    /// Fixture 제출 시각(2026-09-29 08:04 KST)과 같은 날.
    private let sameDay = Fixture.submittedAt.addingTimeInterval(60 * 60)
    private let nextDay = Fixture.submittedAt.addingTimeInterval(24 * 60 * 60)

    @Test func serverStatusValuesMapToCases() {
        #expect(VerificationResult.Status(rawValue: "PROCESSING") == .processing)
        #expect(VerificationResult.Status(rawValue: "APPROVED") == .approved)
        #expect(VerificationResult.Status(rawValue: "REJECTED") == .rejected)
        #expect(VerificationResult.Status(rawValue: "MANUAL_REVIEW") == .manualReview)
    }

    @Test func approvedMatchesFigma() {
        let content = VerificationResultContent(result: Fixture.result(status: .approved), now: sameDay)

        #expect(content.layout == .summary(hero: .check))
        #expect(content.title == "청소 인증이 완료됐어요")
        #expect(content.message == "수고했어요. 활동 시간에 10분을 더했어요")
        #expect(content.rows == [
            .init(label: "담당 구역", value: "본관 2층 복도 A"),
            .init(label: "제출 시각", value: "오늘 08:04"),
            .init(label: "적립", value: "+10분", tone: .earned)
        ])
    }

    /// 실제 서버는 제출 날짜만 준다. 시각 없이 날짜만 보여 준다.
    @Test func unknownSubmittedTimeShowsDateOnly() {
        var result = Fixture.result(status: .approved)
        result.isSubmittedTimeKnown = false
        var processing = Fixture.result(status: .processing)
        processing.isSubmittedTimeKnown = false

        #expect(VerificationResultContent(result: result, now: sameDay).rows[1].value == "오늘")
        #expect(VerificationResultContent(result: result, now: nextDay).rows[1].value == "9월 29일(화)")
        #expect(VerificationResultContent(result: processing, now: sameDay).rows.last?.value == "9월 29일(화)")
    }

    /// 오늘 이미 제출 시트 문구. 시각·상태를 모르면 그 부분을 뺀다.
    @Test func alreadySubmittedSheetMessage() {
        let submittedAt = Fixture.submittedAt
        #expect(VerificationSheet.submittedPhotoStatus(submittedAt: submittedAt, status: .processing) == "오늘 08:04에 보낸 사진을 AI가 확인하고 있어요")
        #expect(VerificationSheet.submittedPhotoStatus(submittedAt: nil, status: .processing) == "오늘 보낸 사진을 AI가 확인하고 있어요")
        #expect(VerificationSheet.submittedPhotoStatus(submittedAt: nil, status: .manualReview) == "오늘 보낸 사진을 선생님이 확인하고 있어요")
        #expect(VerificationSheet.submittedPhotoStatus(submittedAt: nil, status: .approved) == "오늘 보낸 사진이 승인됐어요")
        #expect(VerificationSheet.submittedPhotoStatus(submittedAt: nil, status: .rejected) == "오늘 보낸 사진이 반려됐어요")
        #expect(VerificationSheet.submittedPhotoStatus(submittedAt: nil, status: nil) == "오늘 보낸 사진이 있어요")
    }

    @Test func manualReviewMatchesFigma() {
        let content = VerificationResultContent(result: Fixture.result(status: .manualReview), now: sameDay)

        #expect(content.layout == .summary(hero: .clock))
        #expect(content.title == "선생님이 직접 확인할게요")
        #expect(content.message == "AI가 판단하기 어려운 사진이라 선생님께 보냈어요")
        #expect(content.rows.last == .init(label: "상태", value: "선생님 확인 중", tone: .pending))
    }

    @Test func rejectedShowsReasonAndSubmission() {
        let content = VerificationResultContent(result: Fixture.result(status: .rejected), now: sameDay)

        #expect(content.layout == .rejected(reason: Fixture.rejectionReason))
        #expect(content.title == "인증이 반려됐어요")
        #expect(content.message == "본관 2층 복도 A · 오늘 08:04 제출")
    }

    @Test func processingShowsDetailWithFullDate() {
        let content = VerificationResultContent(result: Fixture.result(status: .processing), now: nextDay)

        #expect(content.layout == .detail)
        #expect(content.title == "9월 29일(화) 인증")
        #expect(content.message == "AI가 사진을 확인하고 있어요")
        #expect(content.rows == [
            .init(label: "상태", value: "검수 중", tone: .pending),
            .init(label: "담당 구역", value: "본관 2층 복도 A"),
            .init(label: "제출 시각", value: "9월 29일(화) 08:04")
        ])
    }

    @Test func submittedOnEarlierDayShowsDate() {
        let content = VerificationResultContent(result: Fixture.result(status: .approved), now: nextDay)

        #expect(content.rows[1].value == "9월 29일(화) 08:04")
    }
}
