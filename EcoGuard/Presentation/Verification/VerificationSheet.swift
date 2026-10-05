import SwiftUI

/// Figma 인증 불가·권한 안내 바텀시트: `인증 시간 아님` (317:134) · `오늘 이미 제출` (317:279) · `카메라 권한 필요` (317:365).
/// 이의신청 사진 다시 찍기에서도 같은 권한 시트를 띄울 수 있도록 내용만 그린다. 띄우는 쪽에서 `.ecoBottomSheet()`를 붙인다.
struct VerificationSheet: View {
    enum Kind: Equatable {
        case outsideWindow(CleaningWindow)
        case alreadySubmitted(submittedAt: Date)
        case permissionRequired
    }

    struct Actions {
        var close: () -> Void = {}
        var openSubmitted: () -> Void = {}
        var openSettings: () -> Void = {}
        var later: () -> Void = {}
    }

    let kind: Kind
    var actions = Actions()

    var body: some View {
        VStack(spacing: 0) {
            HeroIcon(icon: icon, style: .badge, tint: iconTint)
                .padding(.bottom, Metrics.iconBottomPadding)
            Text(title)
                .ecoFont(.title3)
                .foregroundStyle(Color.ecoTextPrimary)
                .accessibilityAddTraits(.isHeader)
                .padding(.bottom, Spacing.sm)
            Text(message)
                .ecoFont(.body2)
                .foregroundStyle(Color.ecoTextSub)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, Spacing.xxl)
            buttons
        }
        .padding(.horizontal, Spacing.screenHorizontal)
        .padding(.top, Metrics.topPadding)
    }

    @ViewBuilder
    private var buttons: some View {
        VStack(spacing: Spacing.sm) {
            switch kind {
            case .outsideWindow:
                EcoButton("확인", action: actions.close)
            case .alreadySubmitted:
                EcoButton("제출한 인증 보기", action: actions.openSubmitted)
                EcoButton("닫기", style: .secondary, action: actions.close)
            case .permissionRequired:
                EcoButton("설정으로 이동", action: actions.openSettings)
                EcoButton("나중에", style: .secondary, action: actions.later)
            }
        }
    }

    private var icon: ImageResource {
        switch kind {
        case .outsideWindow: .iconClockBadge
        case .alreadySubmitted: .iconCheckBadge
        case .permissionRequired: .iconCamBadge
        }
    }

    private var iconTint: Color {
        switch kind {
        case .alreadySubmitted: .ecoPrimary
        case .outsideWindow, .permissionRequired: .ecoTextSub
        }
    }

    private var title: LocalizedStringKey {
        switch kind {
        case .outsideWindow: "지금은 인증 시간이 아니에요"
        case .alreadySubmitted: "오늘은 이미 인증했어요"
        case .permissionRequired: "카메라 권한이 필요해요"
        }
    }

    private var message: LocalizedStringKey {
        switch kind {
        case .outsideWindow(let window):
            "청소 인증은 매일 \(HomeFormatter.window(window))에만 할 수 있어요"
        case .alreadySubmitted(let submittedAt):
            "하루 1번만 제출할 수 있어요.\n오늘 \(HomeFormatter.clockTime(submittedAt))에 보낸 사진을 AI가 확인하고 있어요"
        case .permissionRequired:
            "갤러리 사진은 쓸 수 없어서 카메라 접근이 필요해요. 설정에서 허용해 주세요"
        }
    }
}

extension View {
    /// Figma 바텀시트 모양(위 모서리 24, 흰 배경, 손잡이). 높이는 내용에 맞춘다.
    func ecoBottomSheet() -> some View {
        modifier(EcoBottomSheetModifier())
    }
}

private struct EcoBottomSheetModifier: ViewModifier {
    @State private var height: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.height
            } action: { newHeight in
                height = newHeight
            }
            .presentationDetents(height > 0 ? [.height(height)] : [.medium])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(Metrics.cornerRadius)
            .presentationBackground(Color.ecoCard)
    }
}

private enum Metrics {
    /// Figma 위 여백 10 + 손잡이 4 + 간격 24에서 `HeroIcon` 80 프레임의 위 여백 8을 뺀 값.
    static let topPadding: CGFloat = 30
    /// Figma 아이콘 아래 간격 16에서 `HeroIcon` 80 프레임의 아래 여백 8을 뺀 값.
    static let iconBottomPadding: CGFloat = 8
    static let cornerRadius: CGFloat = 24
}
