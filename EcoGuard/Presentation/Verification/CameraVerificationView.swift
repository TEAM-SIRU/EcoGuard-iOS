import SwiftUI
import UIKit

/// Figma `06 청소 인증` 화면 9개. 촬영 안내 → 촬영 → 확인 → 제출과 인증 불가·권한·실패·시간 초과 상태.
/// 진입점(탭 바 카메라 FAB, 홈 인증 버튼)은 앱 셸(`MainTabView`)이 연결한다.
struct CameraVerificationView: View {
    struct Actions {
        /// 인증 흐름을 닫고 홈으로 돌아간다.
        var close: () -> Void = {}
        /// 이미 인증한 날 `제출한 인증 보기`. 오늘 제출한 인증 결과를 연다.
        var openSubmitted: () -> Void = {}
    }

    let viewModel: CameraVerificationViewModel
    var actions = Actions()

    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        content
            .task {
                guard viewModel.state == .loading else { return }
                await viewModel.load()
            }
            // 마감 시각이 되면 아직 보내기 시작하지 않은 촬영을 시간 초과로 바꾼다.
            .task(id: viewModel.deadline) {
                guard let interval = viewModel.timeUntilDeadline() else { return }
                if interval > 0 {
                    try? await Task.sleep(for: .seconds(interval))
                }
                guard !Task.isCancelled else { return }
                viewModel.expireIfNeeded()
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                viewModel.expireIfNeeded()
            }
            .sheet(isPresented: isSheetPresented) {
                if let kind = sheetKind {
                    VerificationSheet(kind: kind, actions: sheetActions)
                        .ecoBottomSheet()
                        // 인증 불가 시트는 닫으면 흐름이 끝나므로 버튼으로만 닫는다.
                        .interactiveDismissDisabled(viewModel.sheet?.closesFlow ?? false)
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loadFailed:
            VerificationMessageView(
                title: "인증 정보를 불러오지 못했어요",
                message: "네트워크 연결을 확인한 뒤 다시 시도해 주세요.",
                primaryTitle: "다시 시도",
                primaryAction: { await viewModel.load() },
                back: actions.close,
                secondaryAction: actions.close
            )
        case .notAssigned:
            VerificationMessageView(
                title: "아직 배정된 구역이 없어요",
                message: "청소 구역이 배정되면 알려드려요.",
                primaryTitle: "다시 시도",
                primaryAction: { await viewModel.load() },
                back: actions.close,
                secondaryAction: actions.close
            )
        case .guide:
            VerificationGuideView(area: viewModel.session?.area ?? "", back: actions.close) {
                await viewModel.startCapture()
            }
        case .capturing:
            VerificationCaptureView(viewModel: viewModel)
        case .confirming(let captured), .uploading(let captured):
            VerificationConfirmView(
                captured: captured,
                session: viewModel.session,
                isUploading: viewModel.state == .uploading(captured),
                retake: viewModel.retake,
                submit: viewModel.submit
            )
        case .uploadFailed:
            VerificationMessageView(
                title: "사진을 보내지 못했어요",
                message: "네트워크 연결을 확인하고 다시 시도해 주세요.\n\(deadlineText) 전에 업로드를 시작한 사진은 마감 후에도 같은 사진으로 재시도할 수 있어요.\n새 사진으로 바꾸면 마감 후 제출할 수 없어요.",
                primaryTitle: "같은 사진 다시 보내기",
                primaryAction: viewModel.submit,
                back: viewModel.returnToConfirm,
                secondaryAction: actions.close
            )
        case .submitted(let captured, let submittedAt):
            VerificationSubmittedView(captured: captured, submittedAt: submittedAt, area: viewModel.session?.area, goHome: actions.close)
        case .timedOut:
            VerificationMessageView(
                title: "오늘 인증 시간이 끝났어요",
                message: "\(deadlineText)이 지나 새 인증은 제출할 수 없어요.\n마감 전에 업로드를 시작했다면 기존 사진의 업로드를 이어갈 수 있어요.\n이의신청용 촬영은 별도로 가능해요.",
                primaryTitle: "업로드 상태 확인",
                primaryAction: viewModel.checkUploadStatus,
                back: actions.close,
                secondaryAction: actions.close
            )
        }
    }

    /// 안내 문구의 마감 시각(Figma `08:10`). 서버가 정한 인증 시간의 끝이다.
    private var deadlineText: String {
        viewModel.session.map { HomeFormatter.time(minuteOfDay: $0.window.endMinute) } ?? "마감"
    }

    private var isSheetPresented: Binding<Bool> {
        Binding(
            get: { viewModel.sheet != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.dismissSheet()
                }
            }
        )
    }

    private var sheetKind: VerificationSheet.Kind? {
        switch viewModel.sheet {
        case .outsideWindow(let reason):
            viewModel.session.map { .outsideWindow($0.window, reason) }
        case .alreadySubmitted(let submittedAt, let status):
            .alreadySubmitted(submittedAt: submittedAt, status: status)
        case .permissionRequired:
            .permissionRequired
        case nil:
            nil
        }
    }

    private var sheetActions: VerificationSheet.Actions {
        VerificationSheet.Actions(
            close: {
                viewModel.dismissSheet()
                actions.close()
            },
            openSubmitted: {
                viewModel.dismissSheet()
                actions.openSubmitted()
            },
            openSettings: {
                viewModel.dismissSheet()
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            },
            later: viewModel.dismissSheet
        )
    }
}

// MARK: - Preview

private extension CameraVerificationViewModel {
    /// Preview용. Figma 값(본관 2층 복도 A, 마감 5분 32초 전)으로 상태를 바로 만든다.
    static func preview(
        _ state: State,
        sheet: Sheet? = nil,
        availability: VerificationAvailability? = nil
    ) -> CameraVerificationViewModel {
        let now = Date.now
        let availability = availability ?? .open(deadline: now.addingTimeInterval(MockVerificationRepository.Fixture.remainingUntilDeadline))
        let repository = MockVerificationRepository(delay: .zero)
        return CameraVerificationViewModel(
            fetchSessionUseCase: FetchVerificationSessionUseCase(verificationRepository: repository),
            submitPhotoUseCase: SubmitVerificationPhotoUseCase(verificationRepository: repository),
            camera: FakeCameraService(),
            permission: FakeCameraPermission(),
            state: state,
            sheet: sheet,
            session: MockVerificationRepository.Fixture.session(availability, serverNow: now)
        )
    }

    static var previewPhoto: CapturedPhoto {
        let encoded = VerificationPhotoEncoder.encode(FakeCameraService().sampleData)
        let photo = VerificationPhoto(
            id: UUID(),
            jpegData: encoded?.jpegData ?? Data(),
            capturedAt: MockVerificationRepository.Fixture.submittedAt
        )
        return CapturedPhoto(photo: photo, image: encoded?.image ?? UIImage())
    }
}

#Preview("촬영 안내") {
    CameraVerificationView(viewModel: .preview(.guide))
}

#Preview("촬영") {
    CameraVerificationView(viewModel: .preview(.capturing))
}

#Preview("확인") {
    CameraVerificationView(viewModel: .preview(.confirming(CameraVerificationViewModel.previewPhoto)))
}

#Preview("제출 완료 · AI 검수 중") {
    CameraVerificationView(
        viewModel: .preview(.submitted(CameraVerificationViewModel.previewPhoto, submittedAt: MockVerificationRepository.Fixture.submittedAt))
    )
}

#Preview("업로드 실패") {
    CameraVerificationView(viewModel: .preview(.uploadFailed(CameraVerificationViewModel.previewPhoto)))
}

#Preview("시간 초과") {
    CameraVerificationView(viewModel: .preview(.timedOut))
}

#Preview("인증 시간 아님") {
    CameraVerificationView(viewModel: .preview(.guide, sheet: .outsideWindow(.outsideHours), availability: .outsideWindow(.outsideHours)))
}

#Preview("주말 (임시 문구)") {
    CameraVerificationView(viewModel: .preview(.guide, sheet: .outsideWindow(.weekend), availability: .outsideWindow(.weekend)))
}

#Preview("방학 (임시 문구)") {
    CameraVerificationView(viewModel: .preview(.guide, sheet: .outsideWindow(.vacation), availability: .outsideWindow(.vacation)))
}

#Preview("오늘 이미 제출") {
    let submittedAt = MockVerificationRepository.Fixture.submittedAt
    CameraVerificationView(
        viewModel: .preview(
            .guide,
            sheet: .alreadySubmitted(submittedAt: submittedAt, status: .processing),
            availability: .alreadySubmitted(submittedAt: submittedAt, status: .processing)
        )
    )
}

#Preview("카메라 권한 필요") {
    CameraVerificationView(viewModel: .preview(.guide, sheet: .permissionRequired))
}
