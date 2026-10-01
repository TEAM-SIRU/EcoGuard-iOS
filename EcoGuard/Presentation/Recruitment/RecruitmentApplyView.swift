import SwiftUI

/// Figma `04 환경지킴이 신청` (309:169). 학번·이름 자동 표시와 신청 동기 입력은 Figma에 아직 없어
/// 기존 토큰(Info table · 입력 라운드)으로 구성했다. 하단 버튼은 키보드 위로 따라 올라가고, 스크롤하면 키보드가 내려간다.
struct RecruitmentApplyView: View {
    private enum Field: Hashable {
        case motivation
    }

    @State private var viewModel: RecruitmentApplyViewModel
    private let onFinish: (ApplicationOutcome) -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    init(viewModel: RecruitmentApplyViewModel, onFinish: @escaping (ApplicationOutcome) -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onFinish = onFinish
    }

    var body: some View {
        VStack(spacing: 0) {
            EcoNavBar { dismiss() }
            ScrollView {
                VStack(spacing: 0) {
                    EcoPageHeader(
                        title: RecruitmentCopy.Apply.title,
                        subtitle: RecruitmentCopy.Apply.subtitle(capacity: viewModel.capacityPerClass)
                    )
                    .padding(.top, Spacing.sm)
                    VStack(spacing: Spacing.xxl) {
                        EcoInfoTable(rows: [
                            .init(label: RecruitmentCopy.Apply.studentNumberLabel, value: viewModel.applicant.studentNumber),
                            .init(label: RecruitmentCopy.Apply.nameLabel, value: viewModel.applicant.name)
                        ])
                        EcoTextArea(
                            title: RecruitmentCopy.Apply.motivationTitle,
                            prompt: RecruitmentCopy.Apply.motivationPrompt,
                            text: $viewModel.motivation,
                            maxLength: ApplicationMotivation.maxLength,
                            errorMessage: viewModel.validation == .tooLong
                                ? RecruitmentCopy.Apply.motivationTooLong(maxLength: ApplicationMotivation.maxLength)
                                : nil,
                            focus: $focusedField,
                            field: .motivation
                        )
                        .disabled(viewModel.isSubmitting)
                    }
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .padding(.bottom, Spacing.xxl)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        // iOS 26 키보드 툴바 버튼은 키보드 위에 떠서 하단 신청 버튼과 겹친다. 키보드는 스크롤·신청 버튼으로 내린다.
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                if viewModel.submitState == .failed {
                    EcoToast(message: RecruitmentCopy.Apply.failed)
                        .padding(.horizontal, Spacing.screenHorizontal)
                }
                BottomCTA(caption: viewModel.validation == .empty ? RecruitmentCopy.Apply.motivationRequired : nil) {
                    EcoButton(RecruitmentCopy.Apply.submit, isLoading: viewModel.isSubmitting) {
                        focusedField = nil
                        if let outcome = await viewModel.submit() {
                            onFinish(outcome)
                        }
                    }
                    .disabled(viewModel.validation != .valid)
                }
            }
            .background(Color.ecoCard)
        }
        .onChange(of: viewModel.submitState) { _, state in
            guard state == .failed else { return }
            AccessibilityNotification.Announcement(String(localized: RecruitmentCopy.Apply.failed)).post()
        }
    }
}

private struct RecruitmentApplyPreview: View {
    let applyOutcomes: [MockRecruitmentRepository.ApplyOutcome]

    var body: some View {
        NavigationStack {
            RecruitmentApplyView(
                viewModel: DIContainer.preview(applyOutcomes: applyOutcomes)
                    .makeRecruitmentApplyViewModel(applicant: MockRecruitmentRepository.Fixture.applicant, capacityPerClass: 6),
                onFinish: { _ in }
            )
        }
    }
}

#Preview("입력 전") {
    RecruitmentApplyPreview(applyOutcomes: [.approved])
}

#Preview("신청 실패 후 재시도") {
    RecruitmentApplyPreview(applyOutcomes: [.failure, .approved])
}
