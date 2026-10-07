import Foundation
import Observation

/// 앱 셸의 화면 이동 상태. 고른 탭, 홈·전체 탭 안에서 쌓은 화면, 탭 위에 전체 화면으로 띄운 흐름을 들고 있는다.
@Observable
@MainActor
final class MainTabViewModel {
    /// 홈 탭 안에서 push하는 화면. 탭 바를 그대로 두고, 뒤로 가면 홈으로 돌아온다.
    enum HomeRoute: Hashable {
        /// 공지. 홈 공지 카드에서 열면 그 공지가 보이게 스크롤한다.
        case notices(focusedNoticeID: Notice.ID?)
    }

    /// 전체 탭 안에서 push하는 화면. 하단 탭 바를 그대로 둔다(Figma 하단 86pt 프레임 317:1376이 탭 바 자리).
    enum MyPageRoute: Hashable {
        case notices
        case appealHistory
    }

    /// 탭 위에 전체 화면으로 띄우는 흐름. 띄울 때마다 새 ViewModel로 시작한다.
    enum Flow: Identifiable {
        case camera(CameraVerificationViewModel)
        case recruitment
        case applicationResult(ApplicationResultViewModel)
        case verificationResult(id: String, entry: VerificationResultView.Entry)
        case appealForm(AppealTarget)
        case appealResult(Appeal)

        var id: String {
            switch self {
            case .camera: "camera"
            case .recruitment: "recruitment"
            case .applicationResult: "applicationResult"
            case .verificationResult(let id, _): "verificationResult-\(id)"
            case .appealForm(let target): "appealForm-\(target.verificationID)"
            case .appealResult(let appeal): "appealResult-\(appeal.id)"
            }
        }
    }

    /// 흐름 안에서 push하는 화면. 인증 결과 → 이의신청 작성 → 완료처럼 이어진다.
    enum FlowRoute: Hashable {
        case appealForm(AppealTarget)
        case appealSubmitted(Appeal)
    }

    private(set) var selectedTab: MainTab
    /// 홈 탭 `NavigationStack`의 경로.
    var homePath: [HomeRoute] = []
    /// 전체 탭 `NavigationStack`의 경로.
    var myPagePath: [MyPageRoute] = []
    private(set) var presentedFlow: Flow?
    /// 띄운 흐름 안 `NavigationStack`의 경로. 흐름을 닫거나 새로 띄우면 비운다.
    var flowPath: [FlowRoute] = []
    /// 오늘 제출한 인증을 찾지 못해 안내한 횟수. 바뀔 때마다 화면이 토스트를 띄운다.
    private(set) var submissionUnavailableCount = 0
    /// 준비 중인 도움말을 누른 횟수. 바뀔 때마다 화면이 토스트를 띄운다.
    private(set) var helpUnavailableCount = 0
    /// 이 기기에서 방금 낸 인증(서버 ID가 있을 때만). 홈이 오늘 제출분을 아직 받지 못했을 때 대신 연다.
    private var recentSubmission: TodaySubmission?
    private let now: () -> Date

    init(selectedTab: MainTab = .home, now: @escaping () -> Date = Date.init) {
        self.selectedTab = selectedTab
        self.now = now
    }

    /// 이미 고른 홈·전체 탭을 다시 누르면 첫 화면으로 돌아간다.
    func select(_ tab: MainTab) {
        if tab == selectedTab {
            switch tab {
            case .home: homePath = []
            case .myPage: myPagePath = []
            case .area, .records: break
            }
        }
        selectedTab = tab
    }

    /// 홈의 종 아이콘·공지 카드·`공지 보기`. 전체 탭으로 옮기지 않고 홈 위에 쌓아 뒤로 가면 홈으로 돌아온다.
    func openNotices(focusing notice: Notice? = nil) {
        // 공지 위에는 쌓을 화면이 없다. 빠른 연속 탭(종 아이콘과 공지 카드 등)으로 공지 화면이 겹쳐 쌓이지 않게 한다.
        guard homePath.isEmpty else { return }
        homePath.append(.notices(focusedNoticeID: notice?.id))
    }

    func popHome() {
        guard !homePath.isEmpty else { return }
        homePath.removeLast()
    }

    func push(_ route: MyPageRoute) {
        // 같은 화면을 연달아 쌓지 않는다(빠른 연속 탭).
        guard myPagePath.last != route else { return }
        myPagePath.append(route)
    }

    func popMyPage() {
        guard !myPagePath.isEmpty else { return }
        myPagePath.removeLast()
    }

    /// 흐름을 띄운다. 다른 흐름이 떠 있으면 그 흐름을 바꾼다(인증 화면의 `제출한 인증 보기` → 인증 결과).
    func present(_ flow: Flow) {
        flowPath = []
        presentedFlow = flow
    }

    /// 전체 탭의 `도움말`. 디자인이 나오기 전까지 준비 중이라고 안내한다.
    func openHelp() {
        helpUnavailableCount += 1
    }

    /// 활동 기록 행. 그날 제출한 인증의 결과를 연다. 미제출이라 인증이 없으면 열지 않는다.
    func openRecord(_ record: ActivityRecord) {
        guard let verificationID = record.verificationID else { return }
        present(.verificationResult(id: verificationID, entry: .history))
    }

    /// 이미 인증한 날 시트의 `제출한 인증 보기`. 오늘 제출한 인증 결과로 흐름을 바꾼다.
    /// 홈을 다시 불러와도 찾지 못했으면 인증 화면을 닫고 홈에서 안내한다.
    func openTodaySubmission(_ submission: TodaySubmission?) {
        guard let submission = submission ?? todayRecentSubmission else {
            dismissFlow(selecting: .home)
            submissionUnavailableCount += 1
            return
        }
        present(.verificationResult(id: submission.id, entry: .submission))
    }

    /// 카메라에서 사진을 낸 직후. 서버 ID가 없으면(Mock) 기억하지 않는다.
    func verificationSubmitted(_ submission: VerificationSubmission) {
        guard let id = submission.id else { return }
        recentSubmission = TodaySubmission(id: id, submittedAt: submission.submittedAt)
    }

    /// 오늘(KST) 낸 것만. 날이 바뀌면 어제 낸 인증을 오늘 제출분으로 열지 않는다.
    private var todayRecentSubmission: TodaySubmission? {
        guard let recentSubmission else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = HomeFormatter.timeZone
        return calendar.isDate(recentSubmission.submittedAt, inSameDayAs: now()) ? recentSubmission : nil
    }

    /// 흐름을 닫는다. `tab`을 넘기면 그 탭으로 옮긴다(`홈으로`, `활동 기록 보기`).
    /// `홈으로`는 홈 첫 화면을 보여 주므로 홈에 쌓인 화면(공지)을 비운다.
    func dismissFlow(selecting tab: MainTab? = nil) {
        presentedFlow = nil
        flowPath = []
        if let tab {
            if tab == .home {
                homePath = []
            }
            selectedTab = tab
        }
    }

    func pushInFlow(_ route: FlowRoute) {
        guard presentedFlow != nil, flowPath.last != route else { return }
        flowPath.append(route)
    }

    /// 이의신청을 보냈다. 작성 화면이 맨 위일 때만 완료 화면을 쌓는다(떠난 뒤 늦게 끝난 제출이 다른 화면 위에 쌓이지 않게).
    func appealSubmitted(_ appeal: Appeal) {
        let isFormOnTop: Bool
        if let last = flowPath.last {
            if case .appealForm = last { isFormOnTop = true } else { isFormOnTop = false }
        } else if case .appealForm = presentedFlow {
            isFormOnTop = true
        } else {
            isFormOnTop = false
        }
        guard isFormOnTop else { return }
        flowPath.append(.appealSubmitted(appeal))
    }

    /// 흐름 안 뒤로가기. 쌓인 화면이 있으면 하나 빼고, 첫 화면이면 흐름을 닫는다.
    func backInFlow() {
        if flowPath.isEmpty {
            dismissFlow()
        } else {
            flowPath.removeLast()
        }
    }
}
