import SwiftUI

/// Figma `09-3 이의신청 내역` (317:1018). 승인·반려 행은 결과 화면을 연다.
/// 불러오는 중·빈 목록·조회 실패는 Figma에 없어 공용 빈 상태(`EcoEmptyState`)로 그린다.
struct AppealHistoryView: View {
    @State private var viewModel: AppealHistoryViewModel
    @Environment(\.scenePhase) private var scenePhase
    private let back: () -> Void
    private let openResult: (Appeal) -> Void

    init(viewModel: AppealHistoryViewModel, back: @escaping () -> Void, openResult: @escaping (Appeal) -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.back = back
        self.openResult = openResult
    }

    var body: some View {
        VStack(spacing: 0) {
            VerificationNavBar(back: back)
            content
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden()
        .swipeBackEnabled()
        // 앱으로 돌아올 때도 다시 불러 검토 중이던 이의신청 결과를 갱신한다.
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await viewModel.load()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView()
                .accessibilityLabel(Text("이의신청 내역을 불러오는 중"))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed:
            EcoEmptyState(
                icon: .iconList,
                title: "이의신청 내역을 불러오지 못했어요",
                message: "인터넷 연결을 확인하고 다시 시도해 주세요",
                action: .init(title: "다시 시도", perform: viewModel.retry)
            )
        case .loaded(let appeals):
            list(appeals)
        }
    }

    private func list(_ appeals: [Appeal]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("이의신청 내역")
                    .ecoFont(.title1)
                    .foregroundStyle(Color.ecoTextPrimary)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.top, Spacing.sm)
                    .padding(.bottom, Spacing.xl)
                    .padding(.horizontal, Spacing.screenHorizontal)
                if appeals.isEmpty {
                    EcoEmptyState(
                        icon: .iconList,
                        title: "아직 보낸 이의신청이 없어요",
                        message: "반려된 인증에서 이의신청할 수 있어요"
                    )
                    .padding(.top, Spacing.xxxl)
                } else {
                    Text("전체 \(appeals.count)건")
                        .ecoFont(.captionMedium)
                        .foregroundStyle(Color.ecoTextCaption)
                        .padding(.top, Spacing.lg)
                        .padding(.horizontal, Spacing.screenHorizontal)
                    ForEach(appeals) { appeal in
                        row(appeal)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    @ViewBuilder
    private func row(_ appeal: Appeal) -> some View {
        let listRow = EcoListRow(
            icon: nil,
            title: AppealFormatter.verificationTitle(appeal),
            subtitle: AppealFormatter.historySubtitle(appeal),
            horizontalPadding: Spacing.screenHorizontal
        ) {
            StatusChip(status: appeal.status.chipStatus)
        }
        switch appeal.status {
        case .reviewing:
            // 검토 중에는 결과가 없어 열 화면이 없다.
            listRow
        case .approved, .rejected:
            Button {
                openResult(appeal)
            } label: {
                listRow.contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

private extension Appeal.Status {
    var chipStatus: StatusChip.Status {
        switch self {
        case .reviewing: .reviewing
        case .approved: .approved
        case .rejected: .rejected
        }
    }
}

private func historyPreview(
    _ scenario: MockAppealRepository.Scenario,
    delay: Duration = .zero
) -> some View {
    AppealHistoryView(
        viewModel: DIContainer.preview().makeAppealHistoryViewModel(
            repository: MockAppealRepository(scenario: scenario, delay: delay)
        ),
        back: {},
        openResult: { _ in }
    )
}

#Preview("내역") {
    historyPreview(.history)
}

#Preview("빈 목록") {
    historyPreview(.empty)
}

#Preview("조회 실패") {
    historyPreview(.failure)
}

#Preview("불러오는 중") {
    historyPreview(.history, delay: .seconds(3600))
}
