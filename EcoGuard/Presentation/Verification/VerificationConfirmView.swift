import SwiftUI

/// Figma `06-3 청소 인증 · 확인` (239:177). 보내는 중에는 `보내기`가 로딩으로 바뀐다.
struct VerificationConfirmView: View {
    let captured: CameraVerificationViewModel.CapturedPhoto
    let session: VerificationSession?
    let isUploading: Bool
    let retake: () -> Void
    let submit: () async -> Void

    var body: some View {
        VStack(spacing: 0) {
            VerificationNavBar(step: "3/3", back: retake)
                .disabled(isUploading)
            ScrollView {
                VStack(spacing: 0) {
                    VerificationTitle(title: "이 사진으로 보낼까요?", message: "보낸 뒤에는 오늘 다시 제출할 수 없어요")
                    VerificationPhotoView(image: captured.image, placeholder: "촬영한 사진", height: Metrics.photoHeight)
                        .padding(.horizontal, Spacing.screenHorizontal)
                        .padding(.bottom, Spacing.xxl)
                    VerificationInfoTable(rows: rows)
                        .padding(.horizontal, Spacing.screenHorizontal)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .safeAreaInset(edge: .bottom) {
            BottomCTA {
                HStack(spacing: Spacing.sm) {
                    EcoButton("다시 찍기", style: .secondary, action: retake)
                        .disabled(isUploading)
                    EcoButton("보내기", isLoading: isUploading) {
                        await submit()
                    }
                }
            }
        }
    }

    private var rows: [VerificationInfoTable.Row] {
        var rows: [VerificationInfoTable.Row] = []
        if let session {
            rows.append(.init(label: "청소 시간", value: HomeFormatter.window(session.window)))
            rows.append(.init(label: "담당 구역", value: session.area))
        }
        rows.append(.init(label: "촬영 시각", value: "오늘 \(HomeFormatter.clockTime(captured.photo.capturedAt))"))
        return rows
    }
}

private enum Metrics {
    static let photoHeight: CGFloat = 256
}
