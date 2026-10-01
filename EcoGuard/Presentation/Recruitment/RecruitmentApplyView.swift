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
            // 제출 중에는 떠나지 못하게 막는다(결과를 놓치거나 중복 제출되지 않게).
            EcoNavBar { dismiss() }
                .disabled(viewModel.isSubmitting)
            ScrollViewReader { proxy in
                form
                    .onChange(of: focusedField) { _, field in
                        guard field != nil else { return }
                        scrollToMotivation(proxy)
                    }
                    .onChange(of: viewModel.motivation) {
                        guard focusedField == .motivation else { return }
                        scrollToMotivation(proxy)
                    }
                    // 포커스 직후에는 키보드가 아직 올라오는 중이라, 보이는 높이가 줄어든 뒤 한 번 더 맞춘다.
                    .onGeometryChange(for: CGFloat.self) { geometry in
                        geometry.size.height
                    } action: { _ in
                        guard focusedField == .motivation else { return }
                        scrollToMotivation(proxy)
                    }
            }
        }
        // iOS 26 키보드 툴바 버튼은 키보드 위에 떠서 하단 신청 버튼과 겹친다. 키보드는 스크롤·신청 버튼으로 내린다.
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(viewModel.isSubmitting)
        .interactiveDismissDisabled(viewModel.isSubmitting)
        .safeAreaInset(edge: .bottom) {
            bottomBar
        }
        .onChange(of: viewModel.submitState) { _, state in
            guard state == .failed else { return }
            AccessibilityNotification.Announcement(String(localized: RecruitmentCopy.Apply.failed)).post()
        }
        .onChange(of: viewModel.validation) { old, new in
            guard new == .tooLong, old != .tooLong else { return }
            AccessibilityNotification.Announcement(String(localized: tooLongMessage)).post()
        }
    }

    private var tooLongMessage: LocalizedStringResource {
        RecruitmentCopy.Apply.motivationTooLong(maxLength: ApplicationMotivation.maxLength)
    }

    /// 입력란 아래(글자 수·오류)까지 키보드 위에 보이게 한다.
    private func scrollToMotivation(_ proxy: ScrollViewProxy) {
        withAnimation {
            proxy.scrollTo(Field.motivation, anchor: .bottom)
        }
    }

    private var form: some View {
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
                        count: ApplicationMotivation.length(of: viewModel.motivation),
                        maxLength: ApplicationMotivation.maxLength,
                        errorMessage: viewModel.validation == .tooLong ? tooLongMessage : nil,
                        focus: $focusedField,
                        field: .motivation
                    )
                    .disabled(viewModel.isSubmitting)
                    .id(Field.motivation)
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.bottom, Spacing.xxl)
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var bottomBar: some View {
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
