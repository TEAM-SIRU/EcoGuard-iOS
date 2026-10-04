import SwiftUI

/// Figma `09 이의신청` (239:267) 작성 · `09 이의신청 · 제출 실패` (514:165).
/// 하단 버튼은 키보드 위로 따라 올라가고, 스크롤하면 키보드가 내려간다.
struct AppealFormView: View {
    private enum Field: Hashable {
        case message
    }

    @State private var viewModel: AppealFormViewModel
    private let back: () -> Void
    // TODO: 이의신청 진입 연결(별도 이슈)에서 카메라를 띄우고 찍은 사진을 `AppealFormViewModel.addPhoto(_:)`로 넘긴다.
    private let capturePhoto: () -> Void
    private let onSubmitted: (Appeal) -> Void

    @FocusState private var focusedField: Field?

    init(
        viewModel: AppealFormViewModel,
        back: @escaping () -> Void,
        capturePhoto: @escaping () -> Void,
        onSubmitted: @escaping (Appeal) -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        self.back = back
        self.capturePhoto = capturePhoto
        self.onSubmitted = onSubmitted
    }

    var body: some View {
        content
            // iOS 26 키보드 툴바 버튼은 키보드 위에 떠서 하단 버튼과 겹친다. 키보드는 스크롤·보내기 버튼으로 내린다.
            .toolbar(.hidden, for: .navigationBar)
            .navigationBarBackButtonHidden()
            .interactiveDismissDisabled(viewModel.isSubmitting)
            .onChange(of: viewModel.phase) { old, new in
                guard new == .failed, old != .failed else { return }
                AccessibilityNotification.Announcement(String(localized: "이의신청을 보내지 못했어요")).post()
            }
            .onChange(of: viewModel.validation) { old, new in
                guard new == .tooLong, old != .tooLong else { return }
                AccessibilityNotification.Announcement(String(localized: tooLongMessage)).post()
            }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .editing, .submitting:
            editor
        case .failed, .retrying:
            VerificationMessageView(
                title: "이의신청을 보내지 못했어요",
                message: "입력한 내용과 첨부 사진은 유지돼요.\n연결을 확인하고 다시 보내 주세요.\n중복 접수되지 않도록 이전 제출 상태부터 확인해요.",
                primaryTitle: "다시 보내기",
                primaryAction: {
                    if let appeal = await viewModel.retry() {
                        onSubmitted(appeal)
                    }
                },
                back: viewModel.editAfterFailure,
                secondaryTitle: "내용 수정하기",
                secondaryAction: viewModel.editAfterFailure
            )
            // 다시 보내는 중에는 작성 화면으로 돌아가지 못하게 막는다(결과를 놓치거나 중복 제출되지 않게).
            .disabled(viewModel.phase == .retrying)
        }
    }

    private var editor: some View {
        VStack(spacing: 0) {
            // 보내는 중에는 떠나지 못하게 막는다.
            VerificationNavBar(back: back)
                .disabled(viewModel.isSubmitting)
            ScrollViewReader { proxy in
                form
                    .onChange(of: focusedField) { _, field in
                        guard field != nil else { return }
                        scrollToMessage(proxy)
                    }
                    .onChange(of: viewModel.message) {
                        guard focusedField == .message else { return }
                        scrollToMessage(proxy)
                    }
                    // 포커스 직후에는 키보드가 아직 올라오는 중이라, 보이는 높이가 줄어든 뒤 한 번 더 맞춘다.
                    .onGeometryChange(for: CGFloat.self) { geometry in
                        geometry.size.height
                    } action: { _ in
                        guard focusedField == .message else { return }
                        scrollToMessage(proxy)
                    }
            }
        }
        .safeAreaInset(edge: .bottom) {
            BottomCTA {
                EcoButton("이의신청 보내기", isLoading: viewModel.phase == .submitting) {
                    focusedField = nil
                    if let appeal = await viewModel.submit() {
                        onSubmitted(appeal)
                    }
                }
                .disabled(viewModel.validation != .valid)
            }
            .background(Color.ecoCard)
        }
    }

    private var form: some View {
        ScrollView {
            VStack(spacing: 0) {
                VerificationTitle(title: "어떤 점이 달랐나요?", message: "AI·선생님 반려 모두 이의신청할 수 있어요")
                VStack(spacing: Spacing.xxl) {
                    if let reason = viewModel.target.rejectionReason {
                        AppealFormSection(title: "반려 사유") {
                            EcoInfoBox(style: .field, message: reason)
                        }
                        .accessibilityElement(children: .combine)
                    }
                    EcoTextArea(
                        title: "내용",
                        prompt: "예) 복도 끝도 청소했는데 사진에서 잘렸어요",
                        text: $viewModel.message,
                        count: AppealMessage.length(of: viewModel.message),
                        maxLength: AppealMessage.maxLength,
                        errorMessage: viewModel.validation == .tooLong ? tooLongMessage : nil,
                        focus: $focusedField,
                        field: .message
                    )
                    .disabled(viewModel.isSubmitting)
                    .id(Field.message)
                    photos
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.bottom, Spacing.xxl)
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var photos: some View {
        AppealFormSection(title: "사진 다시 찍기 (선택)") {
            HStack(spacing: Spacing.sm) {
                ForEach(viewModel.photos) { photo in
                    EcoPhotoThumbnail(jpegData: photo.jpegData) {
                        viewModel.removePhoto(id: photo.id)
                    }
                }
                if viewModel.photos.count < AppealMessage.maxPhotoCount {
                    EcoAddPhotoTile(count: viewModel.photos.count, maxCount: AppealMessage.maxPhotoCount) {
                        focusedField = nil
                        capturePhoto()
                    }
                }
            }
            .disabled(viewModel.isSubmitting)
            Text("08:10 이후에도 이의신청용 사진은 찍을 수 있어요. 새 청소 인증으로 제출되지는 않아요. 갤러리 사진은 사용할 수 없어요.")
                .ecoFont(.captionRegular)
                .foregroundStyle(Color.ecoTextCaption)
        }
    }

    private var tooLongMessage: LocalizedStringResource {
        "\(AppealMessage.maxLength)자까지 쓸 수 있어요"
    }

    /// 입력란 아래(글자 수·오류)까지 키보드 위에 보이게 한다.
    private func scrollToMessage(_ proxy: ScrollViewProxy) {
        withAnimation {
            proxy.scrollTo(Field.message, anchor: .bottom)
        }
    }
}

/// 작성 화면 항목. 제목(14/20 Medium grey/600) 아래 8 간격으로 내용을 둔다. Figma `Frame` (239:279 · 239:288).
private struct AppealFormSection<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title)
                .ecoFont(.subMedium)
                .foregroundStyle(Color.ecoTextCaption)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AppealFormPreview: View {
    var submitOutcomes: [MockAppealRepository.SubmitOutcome] = [.success]
    var message = ""
    var photoCount = 0
    var phase: AppealFormViewModel.Phase = .editing

    var body: some View {
        NavigationStack {
            AppealFormView(viewModel: viewModel, back: {}, capturePhoto: {}, onSubmitted: { _ in })
        }
    }

    private var viewModel: AppealFormViewModel {
        let viewModel = DIContainer.preview().makeAppealFormViewModel(
            target: MockAppealRepository.Fixture.target,
            repository: MockAppealRepository(submitOutcomes: submitOutcomes, delay: .seconds(1)),
            phase: phase
        )
        viewModel.message = message
        for _ in 0..<photoCount {
            viewModel.addPhoto(Data())
        }
        return viewModel
    }
}

#Preview("작성 전") {
    AppealFormPreview()
}

#Preview("작성 중 · 사진 2장") {
    AppealFormPreview(message: "복도 끝도 청소했는데 사진에서 잘렸어요", photoCount: 2)
}

#Preview("글자 수 초과") {
    AppealFormPreview(message: String(repeating: "가", count: AppealMessage.maxLength + 1))
}

#Preview("제출 실패") {
    AppealFormPreview(message: "복도 끝도 청소했는데 사진에서 잘렸어요", phase: .failed)
}

#Preview("보내기 실패 후 다시 보내기") {
    AppealFormPreview(submitOutcomes: [.failure, .success], message: "복도 끝도 청소했는데 사진에서 잘렸어요")
}
