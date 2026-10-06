import SwiftUI

/// Figma 인증 불가·권한 안내 바텀시트: `인증 시간 아님` (317:134) · `오늘 이미 제출` (317:279) · `카메라 권한 필요` (317:365).
/// 이의신청 사진 다시 찍기에서도 같은 권한 시트를 띄울 수 있도록 내용만 그린다. 띄우는 쪽에서 `.ecoBottomSheet()`를 붙인다.
struct VerificationSheet: View {
    enum Kind: Equatable {
        /// 주말·방학은 안내 화면 디자인 전이라 이 시트에 `VerificationClosedCopy` 임시 문구를 쓴다.
        case outsideWindow(CleaningWindow, VerificationClosedReason)
        /// 서버가 제출 시각·검수 상태를 주지 않으면 nil이다.
        case alreadySubmitted(submittedAt: Date?, status: VerificationResult.Status?)
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
        case .outsideWindow(_, .outsideHours): "지금은 인증 시간이 아니에요"
        case .outsideWindow(_, .weekend): "\(VerificationClosedCopy.weekendTitle)"
        case .outsideWindow(_, .vacation): "\(VerificationClosedCopy.vacationTitle)"
        case .alreadySubmitted: "오늘은 이미 인증했어요"
        case .permissionRequired: "카메라 권한이 필요해요"
        }
    }

    private var message: LocalizedStringKey {
        switch kind {
        case .outsideWindow(let window, .outsideHours):
            "청소 인증은 매일 \(HomeFormatter.window(window))에만 할 수 있어요"
        case .outsideWindow(let window, .weekend):
            "\(VerificationClosedCopy.weekendMessage(window: HomeFormatter.window(window)))"
        case .outsideWindow(_, .vacation):
            "\(VerificationClosedCopy.vacationMessage)"
        case .alreadySubmitted(let submittedAt, let status):
            "하루 1번만 제출할 수 있어요.\n\(Self.submittedPhotoStatus(submittedAt: submittedAt, status: status))"
        case .permissionRequired:
            "갤러리 사진은 쓸 수 없어서 카메라 접근이 필요해요. 설정에서 허용해 주세요"
        }
    }
}

extension VerificationSheet {
    /// Figma 문구는 `오늘 08:04에 보낸 사진을 AI가 확인하고 있어요`(검수 중). 시각·상태를 모르면 그 부분을 뺀다.
    static func submittedPhotoStatus(submittedAt: Date?, status: VerificationResult.Status?) -> String {
        let photo = submittedAt.map { "오늘 \(HomeFormatter.clockTime($0))에 보낸 사진" } ?? "오늘 보낸 사진"
        return switch status {
        case .processing: "\(photo)을 AI가 확인하고 있어요"
        case .manualReview: "\(photo)을 선생님이 확인하고 있어요"
        case .approved: "\(photo)이 승인됐어요"
        case .rejected: "\(photo)이 반려됐어요"
        case nil: "\(photo)이 있어요"
        }
    }
}

/// 주말·방학 안내 임시 문구. Figma에 화면이 없어 `인증 시간 아님` 시트(317:134)에 문구만 바꿔 쓴다. 기획 확정 시 여기만 바꾼다.
enum VerificationClosedCopy {
    static let weekendTitle = "오늘은 인증하는 날이 아니에요"
    static func weekendMessage(window: String) -> String {
        "청소 인증은 평일 \(window)에만 할 수 있어요"
    }

    static let vacationTitle = "지금은 방학 기간이에요"
    static let vacationMessage = "방학 기간에는 청소 인증을 하지 않아요"
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
