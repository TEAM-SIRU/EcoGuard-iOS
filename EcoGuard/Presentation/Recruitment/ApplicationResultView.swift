import SwiftUI

/// Figma `05 신청 결과 · 신청 완료` (246:112) · `신청 중 마감` (246:128).
/// 대기·반려·구역 배정 완료는 Figma에 프레임이 없어 같은 레이아웃에 문구만 새로 썼다. 결과 화면에서는 신청 화면으로 돌아가지 않는다.
struct ApplicationResultView: View {
    @State private var viewModel: ApplicationResultViewModel
    private let onExit: () -> Void

    init(viewModel: ApplicationResultViewModel, onExit: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onExit = onExit
    }

    var body: some View {
        content
            .toolbar(.hidden, for: .navigationBar)
            .navigationBarBackButtonHidden()
            .task {
                await viewModel.load()
            }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded(let outcome):
            resultView(ApplicationResultContent(outcome: outcome))
        case .notApplied:
            RecruitmentMessageView(
                title: "아직 신청하지 않았어요",
                message: "모집 공고에서 신청할 수 있어요.",
                onBack: onExit,
                onExit: onExit
            )
        case .failed:
            RecruitmentMessageView(
                title: "신청 결과를 불러오지 못했어요",
                message: "잠시 후 다시 시도해 주세요.",
                retry: { await viewModel.load() },
                onBack: onExit,
                onExit: onExit
            )
        }
    }

    private func resultView(_ content: ApplicationResultContent) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            VStack(spacing: Spacing.lg) {
                heroIcon(content.icon)
                VStack(spacing: Spacing.sm) {
                    Text(content.title)
                        .ecoFont(.title2)
                        .foregroundStyle(Color.ecoTextPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Text(content.message)
                        .ecoFont(.body2)
                        .foregroundStyle(Color.ecoTextSub)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.bottom, Spacing.xxxl)
            Spacer(minLength: 0)
        }
        .safeAreaInset(edge: .bottom) {
            BottomCTA {
                EcoButton("홈으로", style: content.isPrimaryAction ? .primary : .secondary, action: onExit)
            }
        }
    }

    @ViewBuilder
    private func heroIcon(_ icon: ApplicationResultContent.Icon) -> some View {
        switch icon {
        case .check:
            HeroIcon(icon: .iconCheckHero, style: .result(tint: .ecoPrimary))
        case .cross:
            HeroIcon(icon: .iconXHero, style: .result(tint: .ecoRejected))
        case .clock:
            HeroIcon(icon: .iconClockLarge, style: .badge)
        }
    }
}

private func resultPreview(_ outcome: ApplicationOutcome?) -> some View {
    ApplicationResultView(viewModel: DIContainer.preview().makeApplicationResultViewModel(outcome: outcome), onExit: {})
}

#Preview("승인 · 배정 대기") {
    resultPreview(.applied(MockRecruitmentRepository.Fixture.application(.approved)))
}

#Preview("승인 · 배정 완료") {
    resultPreview(.applied(MockRecruitmentRepository.Fixture.application(.approved, isAreaAssigned: true)))
}

#Preview("대기") {
    resultPreview(.applied(MockRecruitmentRepository.Fixture.application(.pending)))
}

#Preview("반려") {
    resultPreview(.applied(MockRecruitmentRepository.Fixture.application(.rejected)))
}

#Preview("신청 중 마감") {
    resultPreview(.closedWhileApplying)
}

#Preview("신청 내역 없음") {
    resultPreview(nil)
}
