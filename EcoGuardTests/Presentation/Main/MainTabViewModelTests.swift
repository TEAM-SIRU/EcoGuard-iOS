import Testing
@testable import EcoGuard

@MainActor
struct MainTabViewModelTests {
    private let rejectedResultID = "verification-20260922"

    @Test func startsOnHome() {
        let viewModel = MainTabViewModel()

        #expect(viewModel.selectedTab == .home)
        #expect(viewModel.myPagePath.isEmpty)
        #expect(viewModel.presentedFlow == nil)
    }

    @Test(arguments: MainTab.allCases)
    func selectingTabSelectsOnlyThatTab(tab: MainTab) {
        let viewModel = MainTabViewModel()

        viewModel.select(tab)

        #expect(viewModel.selectedTab == tab)
    }

    @Test func selectingAnotherTabThenHomeReturnsHome() {
        let viewModel = MainTabViewModel()

        viewModel.select(.records)
        viewModel.select(.home)

        #expect(viewModel.selectedTab == .home)
    }

    // MARK: - 전체 탭

    @Test func myPageRowsPushInsideMyPageTab() {
        let viewModel = MainTabViewModel(selectedTab: .myPage)

        viewModel.push(.appealHistory)

        #expect(viewModel.selectedTab == .myPage)
        #expect(viewModel.myPagePath == [.appealHistory])
        #expect(viewModel.presentedFlow == nil)
    }

    @Test func pushingSameRouteTwiceStacksOnce() {
        let viewModel = MainTabViewModel(selectedTab: .myPage)

        viewModel.push(.notices)
        viewModel.push(.notices)

        #expect(viewModel.myPagePath == [.notices])
    }

    @Test func backFromPushedScreenReturnsToMyPage() {
        let viewModel = MainTabViewModel(selectedTab: .myPage)
        viewModel.push(.notices)

        viewModel.popMyPage()
        viewModel.popMyPage()

        #expect(viewModel.myPagePath.isEmpty)
    }

    @Test func myPagePathIsKeptWhileVisitingOtherTabs() {
        let viewModel = MainTabViewModel(selectedTab: .myPage)
        viewModel.push(.appealHistory)

        viewModel.select(.home)
        viewModel.select(.myPage)

        #expect(viewModel.myPagePath == [.appealHistory])
    }

    @Test func reselectingMyPageTabPopsToRoot() {
        let viewModel = MainTabViewModel(selectedTab: .myPage)
        viewModel.push(.appealHistory)

        viewModel.select(.myPage)

        #expect(viewModel.myPagePath.isEmpty)
    }

    @Test func cleaningAreaRowSwitchesTab() {
        let viewModel = MainTabViewModel(selectedTab: .myPage)

        viewModel.select(.area)

        #expect(viewModel.selectedTab == .area)
        #expect(viewModel.presentedFlow == nil)
    }

    // MARK: - 인증 결과 → 이의신청

    @Test func rejectedResultOpensAppealFormThenSubmittedInsideFlow() {
        let viewModel = MainTabViewModel(selectedTab: .records)
        let target = MockAppealRepository.Fixture.target
        let appeal = MockAppealRepository.Fixture.reviewing

        viewModel.present(.verificationResult(id: rejectedResultID, entry: .history))
        viewModel.pushInFlow(.appealForm(target))
        viewModel.appealSubmitted(appeal)

        #expect(viewModel.presentedFlow?.id == "verificationResult-\(rejectedResultID)")
        #expect(viewModel.flowPath == [.appealForm(target), .appealSubmitted(appeal)])
        #expect(viewModel.selectedTab == .records)
    }

    @Test func backFromAppealFormReturnsToResult() {
        let viewModel = MainTabViewModel()
        viewModel.present(.verificationResult(id: rejectedResultID, entry: .history))
        viewModel.pushInFlow(.appealForm(MockAppealRepository.Fixture.target))

        viewModel.backInFlow()

        #expect(viewModel.flowPath.isEmpty)
        #expect(viewModel.presentedFlow != nil)
    }

    @Test func backOnFlowRootClosesFlow() {
        let viewModel = MainTabViewModel()
        viewModel.present(.appealForm(MockAppealRepository.Fixture.target))

        viewModel.backInFlow()

        #expect(viewModel.presentedFlow == nil)
    }

    @Test func homeAppealOpensFormAsFlowRoot() {
        let viewModel = MainTabViewModel()
        let appeal = MockAppealRepository.Fixture.reviewing

        viewModel.present(.appealForm(MockAppealRepository.Fixture.target))
        viewModel.appealSubmitted(appeal)

        #expect(viewModel.flowPath == [.appealSubmitted(appeal)])
    }

    @Test func lateSubmissionAfterLeavingFormIsNotStacked() {
        let viewModel = MainTabViewModel()
        viewModel.present(.verificationResult(id: rejectedResultID, entry: .history))
        viewModel.pushInFlow(.appealForm(MockAppealRepository.Fixture.target))
        viewModel.backInFlow()

        viewModel.appealSubmitted(MockAppealRepository.Fixture.reviewing)

        #expect(viewModel.flowPath.isEmpty)
    }

    @Test func pushInFlowWithoutFlowIsIgnored() {
        let viewModel = MainTabViewModel()

        viewModel.pushInFlow(.appealForm(MockAppealRepository.Fixture.target))

        #expect(viewModel.flowPath.isEmpty)
    }

    // MARK: - 이의신청 내역 → 결과

    @Test func appealResultAgainPushesFormInsideFlow() {
        let viewModel = MainTabViewModel(selectedTab: .myPage)
        viewModel.push(.appealHistory)
        let rejected = MockAppealRepository.Fixture.rejected

        viewModel.present(.appealResult(rejected))
        viewModel.pushInFlow(.appealForm(rejected.retryTarget))

        #expect(viewModel.presentedFlow?.id == "appealResult-\(rejected.id)")
        #expect(viewModel.flowPath == [.appealForm(rejected.retryTarget)])
        #expect(viewModel.myPagePath == [.appealHistory])
    }

    @Test func showActivityClosesFlowAndSelectsRecords() {
        let viewModel = MainTabViewModel(selectedTab: .myPage)
        viewModel.push(.appealHistory)
        viewModel.present(.appealResult(MockAppealRepository.Fixture.approved))

        viewModel.dismissFlow(selecting: .records)

        #expect(viewModel.presentedFlow == nil)
        #expect(viewModel.selectedTab == .records)
        // 전체 탭으로 돌아오면 보던 내역이 그대로 있다.
        #expect(viewModel.myPagePath == [.appealHistory])
    }

    @Test func goHomeFromSubmittedClosesFlowAndClearsFlowPath() {
        let viewModel = MainTabViewModel(selectedTab: .records)
        viewModel.present(.verificationResult(id: rejectedResultID, entry: .history))
        viewModel.pushInFlow(.appealForm(MockAppealRepository.Fixture.target))
        viewModel.appealSubmitted(MockAppealRepository.Fixture.reviewing)

        viewModel.dismissFlow(selecting: .home)

        #expect(viewModel.presentedFlow == nil)
        #expect(viewModel.flowPath.isEmpty)
        #expect(viewModel.selectedTab == .home)
    }

    // MARK: - 청소 인증 → 제출한 인증 보기

    @Test func openingSubmittedFromCameraReplacesFlowWithResult() {
        let viewModel = MainTabViewModel()
        viewModel.present(.camera(DIContainer.preview().makeCameraVerificationViewModel()))

        viewModel.present(.verificationResult(id: rejectedResultID, entry: .submission))

        guard case .verificationResult(let id, let entry) = viewModel.presentedFlow else {
            Issue.record("인증 결과 흐름이 아니다")
            return
        }
        #expect(id == rejectedResultID)
        #expect(entry == .submission)
        #expect(viewModel.flowPath.isEmpty)
    }
}
