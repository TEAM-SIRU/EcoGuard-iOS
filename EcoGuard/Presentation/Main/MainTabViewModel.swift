import Observation

/// 앱 셸의 화면 이동 상태. 고른 탭, 전체 탭 안에서 쌓은 화면, 탭 위에 전체 화면으로 띄운 흐름을 들고 있는다.
@Observable
@MainActor
final class MainTabViewModel {
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
    /// 전체 탭 `NavigationStack`의 경로.
    var myPagePath: [MyPageRoute] = []
    private(set) var presentedFlow: Flow?
    /// 띄운 흐름 안 `NavigationStack`의 경로. 흐름을 닫거나 새로 띄우면 비운다.
    var flowPath: [FlowRoute] = []

    init(selectedTab: MainTab = .home) {
        self.selectedTab = selectedTab
    }

    /// 이미 고른 전체 탭을 다시 누르면 첫 화면으로 돌아간다.
    func select(_ tab: MainTab) {
        if tab == .myPage, selectedTab == .myPage {
            myPagePath = []
        }
        selectedTab = tab
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

    /// 흐름을 닫는다. `tab`을 넘기면 그 탭으로 옮긴다(`홈으로`, `활동 기록 보기`).
    func dismissFlow(selecting tab: MainTab? = nil) {
        presentedFlow = nil
        flowPath = []
        if let tab {
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
