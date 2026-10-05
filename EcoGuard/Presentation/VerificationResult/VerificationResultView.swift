import SwiftUI

/// 제출한 청소 인증의 검수 결과. 홈 카드·활동 기록 행·이미 인증한 날 시트에서 같은 화면을 쓰고 `entry`로 진입 경로만 구분한다.
/// 상태별 레이아웃은 `VerificationResultContent`, 조회 실패는 Figma `08 인증 결과 · 조회 실패` (514:107).
struct VerificationResultView: View {
    enum Entry {
        /// 청소 인증 화면의 이미 인증한 날 시트(`제출한 인증 보기`)에서 연다. 승인·선생님 확인 중 화면은 Figma처럼 뒤로가기 없이 `확인`으로 닫는다.
        /// 제출 완료 화면(Figma 06-4)은 `홈으로`만 있어 여기로 오지 않는다.
        case submission
        /// 홈 카드·활동 기록 행에서 연다. 모든 상태에 뒤로가기를 둔다.
        case history
    }

    @State private var viewModel: VerificationResultViewModel
    @Environment(\.scenePhase) private var scenePhase
    private let entry: Entry
    private let close: () -> Void
    private let goHome: () -> Void
    private let appeal: (VerificationResult) -> Void

    init(
        viewModel: VerificationResultViewModel,
        entry: Entry,
        close: @escaping () -> Void,
        goHome: @escaping () -> Void,
        appeal: @escaping (VerificationResult) -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        self.entry = entry
        self.close = close
        self.goHome = goHome
        self.appeal = appeal
    }

    var body: some View {
        content
            .toolbar(.hidden, for: .navigationBar)
            .navigationBarBackButtonHidden()
            // 앱으로 돌아올 때도 다시 불러 검수 중이던 결과를 갱신한다.
            .task(id: scenePhase) {
                guard scenePhase == .active else { return }
                await viewModel.load()
            }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            VStack(spacing: 0) {
                if entry == .history {
                    VerificationNavBar(back: close)
                }
                ProgressView()
                    .accessibilityLabel(Text("결과를 불러오는 중"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        case .loaded(let result):
            loaded(result, content: VerificationResultContent(result: result, now: .now))
        case .failed:
            VerificationMessageView(
                title: "결과를 불러오지 못했어요",
                message: "조회 오류로 제출 결과를 확인하지 못했어요.\n사진을 다시 제출하지 말고 결과 조회를 다시 시도해 주세요.",
                primaryTitle: "결과 다시 확인",
                primaryAction: { await viewModel.retry() },
                back: close,
                secondaryAction: goHome
            )
        }
    }

    @ViewBuilder
    private func loaded(_ result: VerificationResult, content: VerificationResultContent) -> some View {
        switch content.layout {
        case .summary(let hero):
            VerificationResultSummaryView(
                content: content,
                hero: hero,
                photoURL: result.photoURL,
                showsBack: entry == .history,
                close: close
            )
        case .rejected(let reason):
            VerificationResultRejectedView(
                content: content,
                reason: reason,
                photoURL: result.photoURL,
                back: close,
                appeal: { appeal(result) },
                goHome: goHome
            )
        case .detail:
            VerificationResultDetailView(
                content: content,
                photoURL: result.photoURL,
                back: close,
                refresh: { await viewModel.refresh() }
            )
        }
    }
}

/// 승인 (239:213) · 선생님 확인 중 (255:446).
private struct VerificationResultSummaryView: View {
    let content: VerificationResultContent
    let hero: VerificationResultContent.Hero
    let photoURL: URL?
    let showsBack: Bool
    let close: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if showsBack {
                VerificationNavBar(back: close)
            }
            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        VerificationResultHeader(title: content.title, message: content.message, icon: heroIcon)
                            .padding(.bottom, Spacing.xxxl)
                        VerificationResultPhoto(url: photoURL, height: VerificationPhotoView.Height.regular)
                            .padding(.bottom, Spacing.xxl)
                        VerificationResultTable(rows: content.rows)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .frame(minHeight: proxy.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .safeAreaInset(edge: .bottom) {
            BottomCTA {
                EcoButton("확인", action: close)
            }
        }
    }

    private var heroIcon: HeroIcon {
        switch hero {
        case .check: HeroIcon(icon: .iconCheckHero, style: .result(tint: .ecoPrimary))
        case .clock: HeroIcon(icon: .iconClockHero, style: .result(tint: .ecoPendingIcon))
        }
    }
}

/// 반려 (239:240). Figma 아이콘 프레임은 88 × 70(위 40)인데 다른 결과 화면과 같은 80 영역(위 32)에 그린다.
private struct VerificationResultRejectedView: View {
    let content: VerificationResultContent
    let reason: VerificationResult.RejectionReason?
    let photoURL: URL?
    let back: () -> Void
    let appeal: () -> Void
    let goHome: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VerificationNavBar(back: back)
            ScrollView {
                VStack(spacing: 0) {
                    VerificationResultHeader(
                        title: content.title,
                        message: content.message,
                        icon: HeroIcon(icon: .iconAlertHero, style: .result(tint: .ecoRejected))
                    )
                    .padding(.top, Spacing.xxxl)
                    .padding(.bottom, Spacing.xxxl)
                    if let reason {
                        VerificationReviewNote(title: reason.title, guide: reason.guide)
                    }
                    VerificationResultPhoto(url: photoURL, height: VerificationPhotoView.Height.compact)
                        .padding(.vertical, Spacing.lg)
                }
                .padding(.horizontal, Spacing.screenHorizontal)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .safeAreaInset(edge: .bottom) {
            BottomCTA {
                VStack(spacing: Spacing.sm) {
                    EcoButton("이의신청하기", action: appeal)
                    Text("판정이 맞지 않다면 선생님이 직접 확인해요")
                        .ecoFont(.captionRegular)
                        .foregroundStyle(Color.ecoTextCaption)
                        .multilineTextAlignment(.center)
                    EcoButton("홈으로", style: .secondary, action: goHome)
                }
            }
        }
    }
}

/// 검수 중 상세 (317:430). 당겨서 결과를 다시 확인할 수 있다.
private struct VerificationResultDetailView: View {
    let content: VerificationResultContent
    let photoURL: URL?
    let back: () -> Void
    let refresh: () async -> Void

    var body: some View {
        VStack(spacing: 0) {
            VerificationNavBar(back: back)
            ScrollView {
                VStack(spacing: 0) {
                    VerificationTitle(
                        title: LocalizedStringKey(content.title),
                        message: LocalizedStringKey(content.message)
                    )
                    VStack(spacing: 0) {
                        VerificationResultPhoto(url: photoURL, height: VerificationPhotoView.Height.large)
                            .padding(.bottom, Spacing.xxl)
                        VerificationResultTable(rows: content.rows)
                    }
                    .padding(.horizontal, Spacing.screenHorizontal)
                }
            }
            .refreshable {
                await refresh()
            }
        }
    }
}

/// 가운데 아이콘 + 제목 + 설명. 이의신청 완료·결과 화면도 같이 쓴다.
struct VerificationResultHeader: View {
    let title: String
    let message: String
    let icon: HeroIcon

    var body: some View {
        VStack(spacing: Spacing.lg) {
            icon
            VStack(spacing: Spacing.sm) {
                Text(verbatim: title)
                    .ecoFont(.title2)
                    .foregroundStyle(Color.ecoTextPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text(verbatim: message)
                    .ecoFont(.body2)
                    .foregroundStyle(Color.ecoTextSub)
            }
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

/// 제출한 사진. 주소가 없거나 불러오지 못하면 자리표시를 그린다.
/// VoiceOver는 사진이 보일 때만 이미지로 읽고, 자리표시일 때는 사진이 없다는 것을 알린다. 이의신청 결과 화면도 같이 쓴다.
struct VerificationResultPhoto: View {
    private enum Phase {
        case loading
        case loaded
        case unavailable
    }

    let url: URL?
    let height: CGFloat

    @State private var phase: Phase = .loading

    var body: some View {
        VerificationPhotoView(image: nil, placeholder: "제출한 사진", height: height)
            .overlay {
                if let url {
                    AsyncImage(url: url) { asyncPhase in
                        switch asyncPhase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .onAppear { phase = .loaded }
                        case .failure:
                            Color.clear
                                .onAppear { phase = .unavailable }
                        default:
                            Color.clear
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Radius.card))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityAddTraits(phase == .loaded ? .isImage : [])
            .onChange(of: url, initial: true) {
                phase = url == nil ? .unavailable : .loading
            }
    }

    private var accessibilityLabel: Text {
        switch phase {
        case .loaded: Text("제출한 사진")
        case .loading: Text("사진을 불러오는 중")
        case .unavailable: Text("사진을 불러오지 못했어요")
        }
    }
}

private struct VerificationResultTable: View {
    let rows: [VerificationResultContent.Row]

    var body: some View {
        VerificationInfoTable(rows: rows.map { row in
            .init(label: LocalizedStringKey(row.label), value: row.value, valueColor: row.tone.color)
        })
    }
}

private func resultPreview(
    _ scenario: MockVerificationResultRepository.Scenario,
    entry: VerificationResultView.Entry = .submission
) -> some View {
    VerificationResultView(
        viewModel: DIContainer.preview().makeVerificationResultViewModel(
            resultID: MockVerificationResultRepository.Fixture.id,
            repository: MockVerificationResultRepository(scenario: scenario, delay: .zero)
        ),
        entry: entry,
        close: {},
        goHome: {},
        appeal: { _ in }
    )
}

#Preview("승인") {
    resultPreview(.approved)
}

#Preview("반려") {
    resultPreview(.rejected)
}

#Preview("선생님 확인 중") {
    resultPreview(.manualReview)
}

#Preview("검수 중 · 기록에서 열기") {
    resultPreview(.processing, entry: .history)
}

#Preview("승인 · 기록에서 열기") {
    resultPreview(.approved, entry: .history)
}

#Preview("조회 실패") {
    resultPreview(.failure)
}

#Preview("불러오는 중") {
    VerificationResultView(
        viewModel: DIContainer.preview().makeVerificationResultViewModel(
            resultID: MockVerificationResultRepository.Fixture.id,
            repository: MockVerificationResultRepository(delay: .seconds(3600))
        ),
        entry: .submission,
        close: {},
        goHome: {},
        appeal: { _ in }
    )
}
