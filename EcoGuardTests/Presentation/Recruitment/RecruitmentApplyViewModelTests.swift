import Testing
@testable import EcoGuard

@MainActor
struct RecruitmentApplyViewModelTests {
    private typealias Fixture = MockRecruitmentRepository.Fixture

    private func makeViewModel(
        applyOutcomes: [MockRecruitmentRepository.ApplyOutcome],
        delay: Duration = .zero
    ) -> (RecruitmentApplyViewModel, MockRecruitmentRepository) {
        let repository = MockRecruitmentRepository(applyOutcomes: applyOutcomes, delay: delay)
        let viewModel = RecruitmentApplyViewModel(
            applicant: Fixture.applicant,
            capacityPerClass: 6,
            applyRecruitmentUseCase: ApplyRecruitmentUseCase(recruitmentRepository: repository)
        )
        return (viewModel, repository)
    }

    @Test func emptyMotivationCannotSubmit() async {
        let (viewModel, repository) = makeViewModel(applyOutcomes: [.approved])
        viewModel.motivation = "  \n"

        let outcome = await viewModel.submit()

        #expect(viewModel.validation == .empty)
        #expect(!viewModel.canSubmit)
        #expect(outcome == nil)
        #expect(repository.applyCallCount == 0)
    }

    @Test func tooLongMotivationCannotSubmit() async {
        let (viewModel, repository) = makeViewModel(applyOutcomes: [.approved])
        viewModel.motivation = String(repeating: "가", count: ApplicationMotivation.maxLength + 1)

        let outcome = await viewModel.submit()

        #expect(viewModel.validation == .tooLong)
        #expect(outcome == nil)
        #expect(repository.applyCallCount == 0)
    }

    @Test func submitsTrimmedMotivation() async {
        let (viewModel, repository) = makeViewModel(applyOutcomes: [.approved])
        viewModel.motivation = "  교실을 깨끗하게 쓰고 싶어요\n"

        let outcome = await viewModel.submit()

        #expect(outcome == .applied(Fixture.application()))
        #expect(repository.appliedMotivations == ["교실을 깨끗하게 쓰고 싶어요"])
        #expect(viewModel.submitState == .idle)
    }

    @Test func submitWhileSubmittingIsIgnored() async {
        let (viewModel, repository) = makeViewModel(applyOutcomes: [.approved], delay: .milliseconds(200))
        viewModel.motivation = "열심히 할게요"

        let first = Task { await viewModel.submit() }
        while !viewModel.isSubmitting {
            await Task.yield()
        }
        let second = await viewModel.submit()

        #expect(second == nil)
        #expect(await first.value == .applied(Fixture.application()))
        #expect(repository.applyCallCount == 1)
    }

    @Test func failureKeepsInputAndRetrySucceeds() async {
        let (viewModel, repository) = makeViewModel(applyOutcomes: [.failure, .approved])
        viewModel.motivation = "열심히 할게요"

        let failed = await viewModel.submit()
        #expect(failed == nil)
        #expect(viewModel.submitState == .failed)
        #expect(viewModel.motivation == "열심히 할게요")
        #expect(viewModel.canSubmit)

        let retried = await viewModel.submit()

        #expect(retried == .applied(Fixture.application()))
        #expect(repository.applyCallCount == 2)
        #expect(viewModel.submitState == .idle)
    }

    @Test(arguments: [
        (MockRecruitmentRepository.ApplyOutcome.full, ApplicationOutcome.ClosedReason.full),
        (.notInPeriod, .periodEnded)
    ])
    func closedWhileApplyingKeepsReason(
        applyOutcome: MockRecruitmentRepository.ApplyOutcome,
        reason: ApplicationOutcome.ClosedReason
    ) async {
        let (viewModel, _) = makeViewModel(applyOutcomes: [applyOutcome])
        viewModel.motivation = "열심히 할게요"

        #expect(await viewModel.submit() == .closedWhileApplying(reason: reason))
    }

    /// 앞뒤 공백은 길이에 넣지 않는다(서버로 보내는 값 기준).
    @Test func surroundingWhitespaceDoesNotCountTowardLimit() async {
        let (viewModel, repository) = makeViewModel(applyOutcomes: [.approved])
        viewModel.motivation = "  " + String(repeating: "가", count: ApplicationMotivation.maxLength) + "\n"

        #expect(viewModel.validation == .valid)
        #expect(await viewModel.submit() != nil)
        #expect(repository.appliedMotivations.first?.count == ApplicationMotivation.maxLength)
    }

    @Test func alreadyAppliedShowsExistingApplication() async {
        let (viewModel, _) = makeViewModel(applyOutcomes: [.alreadyApplied])
        viewModel.motivation = "열심히 할게요"

        #expect(await viewModel.submit() == .applied(Fixture.application()))
    }

    /// 신청 중 취소되면 실패 안내 없이 입력 화면으로 돌아가고, 다시 신청할 수 있다.
    @Test func cancelledSubmitReturnsToIdleWithoutFailure() async {
        let (viewModel, repository) = makeViewModel(applyOutcomes: [.approved], delay: .milliseconds(300))
        viewModel.motivation = "열심히 할게요"

        let submit = Task { await viewModel.submit() }
        while repository.applyCallCount == 0 {
            await Task.yield()
        }
        submit.cancel()
        #expect(await submit.value == nil)
        #expect(viewModel.submitState == .idle)

        #expect(await viewModel.submit() == .applied(Fixture.application()))
        #expect(repository.applyCallCount == 2)
    }
}
