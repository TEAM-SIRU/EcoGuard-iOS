import SwiftUI

/// 모집 공고 → 신청 → 신청 결과. 화면 이동은 이 기능 안의 `NavigationStack`에서 한다.
/// 진입점(홈 모집 카드)에서 띄우고, 홈으로·뒤로(첫 화면)는 `onExit`으로 닫는다.
struct RecruitmentFlowView: View {
    enum Route: Hashable {
        case apply(Applicant, capacityPerClass: Int)
        case result(ApplicationOutcome)
    }

    private let container: DIContainer
    private let onExit: () -> Void

    @State private var path: [Route] = []
    @State private var noticeViewModel: RecruitmentNoticeViewModel

    init(container: DIContainer, onExit: @escaping () -> Void) {
        self.container = container
        self.onExit = onExit
        _noticeViewModel = State(initialValue: container.makeRecruitmentNoticeViewModel())
    }

    var body: some View {
        NavigationStack(path: $path) {
            RecruitmentNoticeView(
                viewModel: noticeViewModel,
                onApply: { applicant, capacity in
                    path.append(.apply(applicant, capacityPerClass: capacity))
                },
                onExit: onExit
            )
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .apply(let applicant, let capacity):
                    RecruitmentApplyView(
                        viewModel: container.makeRecruitmentApplyViewModel(applicant: applicant, capacityPerClass: capacity),
                        onFinish: { outcome in
                            // 신청 화면을 떠난 뒤 늦게 끝난 제출이 다른 화면 위에 결과를 쌓지 않게 한다.
                            guard case .apply = path.last else { return }
                            path.append(.result(outcome))
                            Task { await noticeViewModel.refresh() }
                        }
                    )
                case .result(let outcome):
                    ApplicationResultView(
                        viewModel: container.makeApplicationResultViewModel(outcome: outcome),
                        onExit: onExit
                    )
                }
            }
        }
    }
}

#Preview {
    RecruitmentFlowView(container: .preview(), onExit: {})
}
