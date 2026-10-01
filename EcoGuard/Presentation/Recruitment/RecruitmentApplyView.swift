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
                        title: "환경지킴이 신청",
                        subtitle: "신청하면 바로 확정돼요.\n반마다 \(viewModel.capacityPerClass)명이 차면 마감돼요."
                    )
                    .padding(.top, Spacing.sm)
                    VStack(spacing: Spacing.xxl) {
                        EcoInfoTable(rows: [
                            .init(label: "학번", value: viewModel.applicant.studentNumber),
                            .init(label: "이름", value: viewModel.applicant.name)
                        ])
                        EcoTextArea(
                            title: "신청 동기",
                            prompt: "환경지킴이로 활동하고 싶은 이유를 적어 주세요",
                            text: $viewModel.motivation,
                            maxLength: ApplicationMotivation.maxLength,
                            errorMessage: viewModel.validation == .tooLong ? "\(ApplicationMotivation.maxLength)자까지 쓸 수 있어요" : nil,
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
                    EcoToast(message: "신청하지 못했어요. 다시 시도해 주세요")
                        .padding(.horizontal, Spacing.screenHorizontal)
                }
                BottomCTA(caption: viewModel.validation == .empty ? "신청 동기를 입력하면 신청할 수 있어요" : nil) {
                    EcoButton("신청하기", isLoading: viewModel.isSubmitting) {
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
            AccessibilityNotification.Announcement(String(localized: "신청하지 못했어요. 다시 시도해 주세요")).post()
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
