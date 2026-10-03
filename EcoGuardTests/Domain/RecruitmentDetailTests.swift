import Foundation
import Testing
@testable import EcoGuard

@MainActor
struct RecruitmentDetailTests {
    private typealias Fixture = MockRecruitmentRepository.Fixture

    @Test func openWithSeatsLeftIsOpen() {
        let detail = Fixture.detail(phase: .open, appliedCount: 4)

        #expect(detail.status == .open)
        #expect(detail.remainingSeats == 2)
    }

    @Test func openButFullIsFull() {
        #expect(Fixture.detail(phase: .open, appliedCount: 6).status == .full)
    }

    @Test func overCapacityDoesNotGoNegative() {
        let detail = Fixture.detail(phase: .open, appliedCount: 7)

        #expect(detail.remainingSeats == 0)
        #expect(detail.status == .full)
    }

    @Test(arguments: [
        (RecruitmentDetail.Phase.upcoming, RecruitmentStatus.upcoming),
        (.ended, .ended)
    ])
    func outsidePeriodFollowsServerPhase(phase: RecruitmentDetail.Phase, expected: RecruitmentStatus) {
        #expect(Fixture.detail(phase: phase, appliedCount: 0).status == expected)
    }

    @Test(arguments: [RecruitmentDetail.Phase.open, .upcoming, .ended])
    func myApplicationWinsOverPhaseAndCapacity(phase: RecruitmentDetail.Phase) {
        let application = Fixture.application()
        let detail = Fixture.detail(phase: phase, appliedCount: 6, myApplication: application)

        #expect(detail.status == .applied(application))
    }
}
