import SwiftUI

/// 촬영 실패 토스트 문구. 제네릭 타입에는 정적 저장 프로퍼티를 둘 수 없어 밖에 둔다.
private let captureFailedMessage: LocalizedStringResource = "사진을 찍지 못했어요. 다시 시도해 주세요"

/// Figma `06-2 청소 인증 · 촬영` (239:150) 모양의 촬영 화면. 카메라 미리보기 위에 촬영 가이드 프레임을 겹친다.
/// 청소 인증 촬영과 이의신청 사진 다시 찍기가 같이 쓴다. 제목 아래 `banner`에 인증 마감 카운트다운 등을 둔다.
struct CameraCaptureScreen<Banner: View>: View {
    let capture: CameraCapture
    let title: Text
    var subtitle: LocalizedStringKey?
    /// 셔터를 누를 수 있는지. 쓰는 쪽이 세션 상태 외의 조건(인증 상태 등)을 더해 넘긴다.
    let canTakePhoto: Bool
    let close: () -> Void
    let takePhoto: () async -> Void
    @ViewBuilder var banner: Banner

    @State private var isShowingFailureToast = false

    var body: some View {
        VStack(spacing: 0) {
            header
            banner
            viewfinder
            controls
        }
        .background(Color.ecoCameraBackground.ignoresSafeArea())
        // 촬영 실패 토스트는 Figma 정의가 없어 로그인 실패 토스트와 같은 모양으로 위쪽에 띄운다.
        .overlay(alignment: .top) {
            if isShowingFailureToast {
                EcoToast(message: captureFailedMessage)
                    .padding(.top, Spacing.sm)
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .transition(.opacity)
            }
        }
        .animation(.default, value: isShowingFailureToast)
        .task {
            await capture.run()
        }
        .onDisappear {
            capture.stop()
        }
        .task(id: capture.captureFailureCount) {
            guard capture.captureFailureCount > 0 else { return }
            AccessibilityNotification.Announcement(String(localized: captureFailedMessage)).post()
            isShowingFailureToast = true
            // 다시 실패하면 이 작업은 취소되고 새 작업이 시간을 처음부터 센다.
            guard (try? await Task.sleep(for: EcoToast.displayDuration)) != nil else { return }
            isShowingFailureToast = false
        }
    }

    private var header: some View {
        HStack {
            EcoIconButton(icon: .iconCloseLarge, color: .ecoOnCamera, accessibilityLabel: "닫기", action: close)
            Spacer()
            VStack(spacing: 0) {
                title
                    .ecoFont(.body1Bold)
                    .foregroundStyle(Color.ecoOnCamera)
                if let subtitle {
                    Text(subtitle)
                        .ecoFont(.captionRegular)
                        .foregroundStyle(Color.ecoOnCameraSub)
                }
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
                CameraPreviewView(source: capture.camera.previewSource)
            }
            .clipped()
            .overlay {
                guideFrame
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .padding(.vertical, Spacing.xl)
            }
            .overlay {
                if capture.isCameraUnavailable {
                    unavailableNotice
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text("카메라 미리보기"))
    }

    /// 세션 중단·오류 안내. Figma 정의가 없어 촬영 안내 말풍선과 같은 모양을 가운데에 둔다.
    private var unavailableNotice: some View {
        Text("카메라를 사용할 수 없어요")
            .ecoFont(.subMedium)
            .foregroundStyle(Color.ecoOnCamera)
            .padding(.horizontal, Metrics.guideLabelHorizontalPadding)
            .padding(.vertical, Spacing.sm)
            .background(Color.ecoCameraGuideBackground, in: Capsule())
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
                Task { await takePhoto() }
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
            .disabled(!canTakePhoto)
            .opacity(canTakePhoto ? 1 : Metrics.disabledOpacity)
            .accessibilityLabel(Text("촬영"))
            Spacer()
            Button {
                Task { await capture.switchCamera() }
            } label: {
                Image(.iconFlip)
                    .foregroundStyle(Color.ecoOnCamera)
                    .frame(width: Metrics.flipSize, height: Metrics.flipSize)
                    .background(Color.ecoCameraSurface, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(!capture.canSwitchCamera)
            .opacity(capture.canSwitchCamera ? 1 : Metrics.disabledOpacity)
            .accessibilityLabel(Text("카메라 전환"))
        }
        .padding(.horizontal, Metrics.controlsHorizontalPadding)
        .padding(.top, Metrics.controlsTopPadding)
        // Figma 하단 44 중 34는 홈 인디케이터(safe area)다.
        .padding(.bottom, Metrics.controlsBottomPadding)
    }
}

extension CameraCaptureScreen where Banner == EmptyView {
    init(
        capture: CameraCapture,
        title: Text,
        subtitle: LocalizedStringKey? = nil,
        canTakePhoto: Bool,
        close: @escaping () -> Void,
        takePhoto: @escaping () async -> Void
    ) {
        self.init(capture: capture, title: title, subtitle: subtitle, canTakePhoto: canTakePhoto, close: close, takePhoto: takePhoto) {
            EmptyView()
        }
    }
}

private enum Metrics {
    static let headerButtonSize: CGFloat = 44
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
    /// 셔터·전환 버튼 비활성 모습. Figma 정의가 없어 흐리게만 한다.
    static let disabledOpacity: Double = 0.4
}
