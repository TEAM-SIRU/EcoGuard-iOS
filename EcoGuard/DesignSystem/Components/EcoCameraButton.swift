import SwiftUI

/// Figma `Camera FAB` (255:27). 60pt 초록 원 + 흰 테두리 4 + 카메라 26.
/// 비활성은 회색 원에 그림자 없음 (모집 기간 255:579).
struct EcoCameraButton: View {
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Image(.iconCamLarge)
                .foregroundStyle(Color.ecoOnPrimary)
                .frame(width: Metrics.size, height: Metrics.size)
                .background {
                    if isEnabled {
                        circle.ecoShadow(.cameraButton)
                    } else {
                        circle
                    }
                }
                .contentShape(Circle())
        }
        .buttonStyle(CameraButtonStyle())
        .accessibilityLabel(Text("청소 인증하기"))
    }

    private var circle: some View {
        Circle()
            .fill(isEnabled ? Color.ecoPrimary : Color.ecoDisabled)
            .overlay {
                Circle().strokeBorder(Color.ecoCard, lineWidth: Metrics.borderWidth)
            }
    }
}

/// 기본 버튼 스타일은 비활성일 때 한 번 더 흐리게 그려 Figma 회색과 달라진다.
private struct CameraButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}

private enum Metrics {
    static let size: CGFloat = 60
    static let borderWidth: CGFloat = 4
}

#Preview {
    HStack(spacing: Spacing.xxl) {
        EcoCameraButton {}
        EcoCameraButton {}
            .disabled(true)
    }
    .padding(Spacing.xxl)
}
