import Testing
@testable import EcoGuard

@MainActor
struct ApplicationResultTests {
    private typealias Fixture = MockRecruitmentRepository.Fixture

    @Test func approvedBeforeAssignmentWaitsForArea() {
        let content = ApplicationResultContent(outcome: .applied(Fixture.application(.approved)))

        #expect(content.icon == .check)
        #expect(content.title == "환경지킴이가 됐어요")
        #expect(content.message == "4번째로 신청했어요 · 9월 1일(화) 12:34\n청소 구역이 배정되면 알려드려요.")
        #expect(content.isPrimaryAction)
    }

    @Test func approvedAfterAssignmentPointsToHome() {
        let content = ApplicationResultContent(outcome: .applied(Fixture.application(.approved, isAreaAssigned: true)))

        #expect(content.message.hasSuffix("청소 구역이 배정됐어요. 홈에서 확인해 주세요."))
    }

    @Test func pendingShowsOrderAndWaits() {
        let content = ApplicationResultContent(outcome: .applied(Fixture.application(.pending)))

        #expect(content.icon == .clock)
        #expect(content.title == "신청했어요")
        #expect(content.message.hasPrefix("4번째로 신청했어요"))
    }

    @Test func rejectedUsesSecondaryAction() {
        let content = ApplicationResultContent(outcome: .applied(Fixture.application(.rejected)))

        #expect(content.icon == .cross)
        #expect(content.title == "신청이 반려됐어요")
        #expect(!content.isPrimaryAction)
    }

    @Test func closedWhileApplyingMatchesFigma() {
        let content = ApplicationResultContent(outcome: .closedWhileApplying)

        #expect(content.title == "신청하지 못했어요")
        #expect(content.message == "신청하는 사이 모집 인원이 모두 찼어요.\n다음 모집 때 다시 신청해 주세요.")
        #expect(!content.isPrimaryAction)
    }

    private func makeViewModel(outcome: ApplicationOutcome?, scenario: MockRecruitmentRepository.Scenario) -> ApplicationResultViewModel {
        let repository = MockRecruitmentRepository(scenario: scenario, delay: .zero)
        return ApplicationResultViewModel(
            outcome: outcome,
            fetchMyApplicationUseCase: FetchMyApplicationUseCase(recruitmentRepository: repository)
        )
    }

    @Test func outcomeFromSubmissionSkipsLoading() async {
        let viewModel = makeViewModel(outcome: .closedWhileApplying, scenario: .failure)

        await viewModel.load()

        #expect(viewModel.state == .loaded(.closedWhileApplying))
    }

    @Test(arguments: [MockRecruitmentRepository.Scenario.applied, .open, .failure])
    func loadsMyApplicationWhenOpenedAlone(scenario: MockRecruitmentRepository.Scenario) async {
        let expected: ApplicationResultViewModel.State = switch scenario {
        case .applied: .loaded(.applied(Fixture.application(.approved)))
        case .failure: .failed
        default: .notApplied
        }
        let viewModel = makeViewModel(outcome: nil, scenario: scenario)

        await viewModel.load()

        #expect(viewModel.state == expected)
    }
}
