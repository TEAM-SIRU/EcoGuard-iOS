import SwiftUI

/// Figma `10 공지 · 조회 실패` (317:1347).
// TODO: 공지 목록·상세·로딩은 Figma 디자인이 없다(디자인 대기). 디자인이 나오면 자리표시를 바꾼다.
struct NoticeView: View {
    let viewModel: NoticeViewModel
    /// 홈 공지 카드에서 열었을 때 그 공지. 상세 디자인이 없어 목록에서 그 공지가 보이게 스크롤한다.
    var focusedNoticeID: Notice.ID?
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            EcoNavBar(onBack: onBack)
            title
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.ecoCard)
        .task {
            // 불러온 화면이 없으면(처음, 화면을 떠나 취소됨) 다시 불러온다. 실패 화면은 사용자가 다시 시도한다.
            guard viewModel.state == .loading else { return }
            await viewModel.load()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            // TODO: 디자인 대기. 로딩 자리표시.
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed:
            EcoEmptyState(
                icon: .iconMapHero,
                title: "공지를 불러오지 못했어요",
                message: "잠시 후 다시 시도해 주세요",
                action: .init(title: "다시 시도", perform: viewModel.load)
            )
        case .loaded(let notices):
            // TODO: 디자인 대기. 목록 자리표시로 제목만 보여 준다. 상세가 나오면 `focusedNoticeID`로 상세를 연다.
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        ForEach(notices) { notice in
                            Text(notice.title)
                                .ecoFont(.body1)
                                .foregroundStyle(Color.ecoTextPrimary)
                                .id(notice.id)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Spacing.screenHorizontal)
                }
                .onAppear {
                    guard let focusedNoticeID else { return }
                    proxy.scrollTo(focusedNoticeID, anchor: .top)
                }
            }
        }
    }

    private var title: some View {
        Text("공지")
            .ecoFont(.title1)
            .foregroundStyle(Color.ecoTextPrimary)
            .accessibilityAddTraits(.isHeader)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.xl)
    }
}

private func noticePreview(_ scenario: MockNoticeRepository.Scenario, delay: Duration = .zero) -> some View {
    NoticeView(
        viewModel: DIContainer.preview().makeNoticeViewModel(repository: MockNoticeRepository(scenario: scenario, delay: delay)),
        onBack: {}
    )
}

#Preview("조회 실패") { noticePreview(.failure) }
#Preview("목록(자리표시)") { noticePreview(.loaded) }
#Preview("로딩(자리표시)") { noticePreview(.loaded, delay: .seconds(3600)) }
