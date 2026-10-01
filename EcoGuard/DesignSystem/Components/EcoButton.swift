import SwiftUI

/// Figma `Button/primary` · `Button/secondary` · `Button/disabled` (높이 56, 풀와이드, radius 16).
/// 비활성은 `.disabled(true)`로 표현한다. 로딩 중에는 탭을 막고 loader 아이콘을 돌린다.
struct EcoButton: View {
    enum Style {
        case primary
        case secondary
    }

    private let title: LocalizedStringKey
    private let style: Style
    private let leadingIcon: ImageResource?
    private let isLoading: Bool
    private let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    init(
        _ title: LocalizedStringKey,
        style: Style = .primary,
        leadingIcon: ImageResource? = nil,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.leadingIcon = leadingIcon
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                if isLoading {
                    SpinningLoaderIcon()
                } else if let leadingIcon {
                    Image(leadingIcon)
                        .resizable()
                        .frame(width: Metrics.iconSize, height: Metrics.iconSize)
                        .accessibilityHidden(true)
                }
                Text(title)
                    .ecoFont(appearance.textStyle)
                    .lineLimit(1)
            }
            .foregroundStyle(appearance.foreground)
            .frame(maxWidth: .infinity)
            .frame(height: Metrics.height)
            .background(appearance.background, in: RoundedRectangle(cornerRadius: Radius.button))
            .contentShape(RoundedRectangle(cornerRadius: Radius.button))
            .opacity(isLoading ? Metrics.loadingOpacity : 1)
        }
        .buttonStyle(EcoButtonStyle())
        .disabled(isLoading)
    }

    private var appearance: Appearance {
        // 로딩은 primary 색을 유지한 채 흐리게 보인다(Figma 01 로그인 · 로딩, 238:157).
        if !isEnabled && !isLoading {
            return Appearance(textStyle: .button, foreground: .ecoDisabled, background: .ecoDivider)
        }
        switch style {
        case .primary:
            return Appearance(textStyle: .buttonLarge, foreground: .ecoOnPrimary, background: .ecoPrimary)
        case .secondary:
            return Appearance(textStyle: .button, foreground: .ecoTextSub, background: .ecoDivider)
        }
    }
}

private extension EcoButton {
    struct Appearance {
        let textStyle: EcoTextStyle
        let foreground: Color
        let background: Color
    }

    enum Metrics {
        static let height: CGFloat = 56
        static let iconSize: CGFloat = 20
        static let loadingOpacity: Double = 0.72
    }
}

/// `.plain`은 비활성일 때 한 번 더 흐리게 그려 Figma 비활성·로딩 색과 달라진다. 색은 `EcoButton`이 정하고 여기서는 손대지 않는다.
/// 눌림 상태는 Figma에 정의가 없어 따로 표현하지 않는다.
private struct EcoButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}

/// `icon/loader`를 한 바퀴씩 계속 돌린다. 동작 줄이기 설정이면 멈춰 둔다.
private struct SpinningLoaderIcon: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isRotating = false

    var body: some View {
        Image(.iconLoader)
            .resizable()
            .frame(width: Metrics.size, height: Metrics.size)
            .rotationEffect(.degrees(isRotating ? 360 : 0))
            .animation(
                reduceMotion ? nil : .linear(duration: Metrics.duration).repeatForever(autoreverses: false),
                value: isRotating
            )
            .onAppear { isRotating = !reduceMotion }
            .accessibilityHidden(true)
    }

    private enum Metrics {
        static let size: CGFloat = 20
        static let duration: Double = 1
    }
}

#Preview {
    VStack(spacing: Spacing.md) {
        EcoButton("청소 인증하기", leadingIcon: .iconCam) {}
        EcoButton("다시 찍기", style: .secondary) {}
        EcoButton("이의신청 보내기") {}
            .disabled(true)
        EcoButton("지금은 인증 시간이 아니에요", leadingIcon: .iconClock) {}
            .disabled(true)
        EcoButton("로그인하는 중이에요", isLoading: true) {}
    }
    .padding(.horizontal, Spacing.screenHorizontal)
}
