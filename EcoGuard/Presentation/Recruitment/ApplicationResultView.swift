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
                title: RecruitmentCopy.Result.notAppliedTitle,
                message: RecruitmentCopy.Result.notAppliedMessage,
                onBack: onExit,
                onExit: onExit
            )
        case .failed:
            RecruitmentMessageView(
                title: RecruitmentCopy.Result.failedTitle,
                message: RecruitmentCopy.Result.failedMessage,
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
                EcoButton(RecruitmentCopy.Common.home, style: content.isPrimaryAction ? .primary : .secondary, action: onExit)
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
        }
    }
}

private func resultPreview(_ outcome: ApplicationOutcome?) -> some View {
    ApplicationResultView(viewModel: DIContainer.preview().makeApplicationResultViewModel(outcome: outcome), onExit: {})
}

#Preview("승인 · 배정 대기") {
    resultPreview(.applied(MockRecruitmentRepository.Fixture.application()))
}

#Preview("승인 · 배정 완료") {
    resultPreview(.applied(MockRecruitmentRepository.Fixture.application(isAreaAssigned: true)))
}

#Preview("신청 중 마감") {
    resultPreview(.closedWhileApplying(reason: .full))
}

#Preview("신청 중 기간 종료") {
    resultPreview(.closedWhileApplying(reason: .periodEnded))
}

#Preview("신청 내역 없음") {
    resultPreview(nil)
}
