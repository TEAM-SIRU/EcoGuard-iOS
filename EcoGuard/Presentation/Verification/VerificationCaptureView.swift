import SwiftUI

/// Figma `06-2 청소 인증 · 촬영` (239:150). 카메라 미리보기 위에 촬영 가이드 프레임을 겹친다.
struct VerificationCaptureView: View {
    let viewModel: CameraVerificationViewModel

    var body: some View {
        VStack(spacing: 0) {
            header
            if let deadline = viewModel.deadline {
                DeadlineCountdownBar(deadline: deadline, endMinute: viewModel.session?.window.endMinute)
            }
            viewfinder
            controls
        }
        .background(Color.ecoCameraBackground.ignoresSafeArea())
        .task {
            await viewModel.startCamera()
        }
        .onDisappear {
            viewModel.stopCamera()
        }
    }

    private var header: some View {
        HStack {
            EcoIconButton(icon: .iconCloseLarge, color: .ecoOnCamera, accessibilityLabel: "닫기") {
                viewModel.cancelCapture()
            }
            Spacer()
            VStack(spacing: 0) {
                Text(verbatim: viewModel.session?.area ?? "")
                    .ecoFont(.body1Bold)
                    .foregroundStyle(Color.ecoOnCamera)
                Text("2/3 · 촬영")
                    .ecoFont(.captionRegular)
                    .foregroundStyle(Color.ecoOnCameraSub)
            }
            .accessibilityElement(children: .combine)
            Spacer()
            // 제목을 가운데에 두기 위한 닫기 버튼 크기의 빈 자리.
            Color.clear
                .frame(width: Metrics.headerButtonSize, height: Metrics.headerButtonSize)
        }
        .padding(.leading, Spacing.md)
        .padding(.trailing, Spacing.xl)
        .padding(.top, Spacing.xs)
        .padding(.bottom, Spacing.md)
    }

    private var viewfinder: some View {
        // 미리보기는 채워 그리면 영역보다 커지므로 배경 색 위에 겹쳐 영역 크기를 고정한다.
        Color.ecoCameraSurface
            .overlay {
                CameraPreviewView(source: viewModel.camera.previewSource)
            }
            .clipped()
            .overlay {
                guideFrame
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .padding(.vertical, Spacing.xl)
            }
            .accessibilityElement()
            .accessibilityLabel(Text("카메라 미리보기"))
    }

    private var guideFrame: some View {
        RoundedRectangle(cornerRadius: Radius.card)
            .strokeBorder(Color.ecoOnCamera, style: StrokeStyle(lineWidth: Metrics.guideLineWidth, dash: Metrics.guideDash))
            .overlay(alignment: .bottom) {
                Text("구역 전체가 프레임 안에 들어오게 맞춰 주세요")
                    .ecoFont(.subMedium)
                    .foregroundStyle(Color.ecoOnCamera)
                    .padding(.horizontal, Metrics.guideLabelHorizontalPadding)
                    .padding(.vertical, Spacing.sm)
                    .background(Color.ecoCameraGuideBackground, in: Capsule())
                    .padding(Spacing.xl)
            }
    }

    private var controls: some View {
        HStack {
            Color.clear
                .frame(width: Metrics.flipSize, height: Metrics.flipSize)
            Spacer()
            Button {
                Task { await viewModel.takePhoto() }
            } label: {
                ZStack {
                    Circle()
                        .strokeBorder(Color.ecoOnCamera, lineWidth: Metrics.shutterRingWidth)
                    Circle()
                        .fill(Color.ecoOnCamera)
                        .padding(Metrics.shutterRingWidth + Metrics.shutterInset)
                }
                .frame(width: Metrics.shutterSize, height: Metrics.shutterSize)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isTakingPhoto)
            .accessibilityLabel(Text("촬영"))
            Spacer()
            Button {
                Task { await viewModel.switchCamera() }
            } label: {
                Image(.iconFlip)
                    .foregroundStyle(Color.ecoOnCamera)
                    .frame(width: Metrics.flipSize, height: Metrics.flipSize)
                    .background(Color.ecoCameraSurface, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("카메라 전환"))
        }
        .padding(.horizontal, Metrics.controlsHorizontalPadding)
        .padding(.top, Metrics.controlsTopPadding)
        // Figma 하단 44 중 34는 홈 인디케이터(safe area)다.
        .padding(.bottom, Metrics.controlsBottomPadding)
    }
}

/// Figma `인증 마감 카운트다운` (512:179). 남은 시간은 서버 마감 시각까지를 1초마다 다시 그린다.
private struct DeadlineCountdownBar: View {
    let deadline: Date
    let endMinute: Int?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(label(now: context.date))
                .ecoFont(.body2)
                .foregroundStyle(Color.ecoOnPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: Metrics.countdownHeight)
                .background(Color.ecoPrimary)
        }
    }

    private func label(now: Date) -> String {
        let remaining = HomeFormatter.countdown(deadline.timeIntervalSince(now))
        guard let endMinute else { return "남은 시간 \(remaining)" }
        return "남은 시간 \(remaining) · \(HomeFormatter.time(minuteOfDay: endMinute)) 마감"
    }
}

private enum Metrics {
    static let headerButtonSize: CGFloat = 44
    static let countdownHeight: CGFloat = 40
    static let guideLineWidth: CGFloat = 2
    /// Figma 점선 간격은 값이 없어 스크린샷에 맞춰 잡았다.
    static let guideDash: [CGFloat] = [10, 6]
    static let guideLabelHorizontalPadding: CGFloat = 14
    static let shutterSize: CGFloat = 80
    static let shutterRingWidth: CGFloat = 4
    static let shutterInset: CGFloat = 6
    static let flipSize: CGFloat = 48
    static let controlsHorizontalPadding: CGFloat = 48
    static let controlsTopPadding: CGFloat = 28
    static let controlsBottomPadding: CGFloat = 10
}
