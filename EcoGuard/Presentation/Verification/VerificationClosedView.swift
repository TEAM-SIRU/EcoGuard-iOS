import SwiftUI

/// Figma `06 인증 불가 · 주말` (823:3610) · `방학` (823:3645). 인증하지 않는 날 카메라를 누르면 시트 대신 띄우는 전체 화면.
/// 가운데 회색 해 아이콘 · 제목 · 설명, 하단 `홈으로`.
struct VerificationClosedView: View {
    let reason: VerificationClosedReason
    let goHome: () -> Void

    var body: some View {
        ScrollView {
            EcoMessageContent(icon: .iconSun, iconTint: .ecoTextMuted, title: title, message: message)
                .containerRelativeFrame(.vertical, alignment: .center)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            BottomCTA {
                EcoButton("홈으로", action: goHome)
            }
        }
        .background(Color.ecoCanvas)
    }

    private var title: LocalizedStringKey {
        switch reason {
        case .vacation: "\(VerificationClosedCopy.vacationTitle)"
        case .weekend, .outsideHours: "\(VerificationClosedCopy.weekendTitle)"
        }
    }

    private var message: LocalizedStringKey {
        switch reason {
        case .vacation: "\(VerificationClosedCopy.vacationMessage)"
        case .weekend, .outsideHours: "\(VerificationClosedCopy.weekendMessage)"
        }
    }
}

/// 주말·방학 안내 문구. Figma `06 인증 불가 · 주말 / 방학`.
enum VerificationClosedCopy {
    static let weekendTitle = "오늘은 인증하는 날이 아니에요"
    static let weekendMessage = "청소 인증은 평일에만 해요. 월요일에 다시 만나요"

    static let vacationTitle = "방학에는 인증하지 않아요"
    static let vacationMessage = "다음 학기 모집 공고가 올라오면 홈에서 알려 드려요"
}

#Preview("주말") { VerificationClosedView(reason: .weekend, goHome: {}) }
#Preview("방학") { VerificationClosedView(reason: .vacation, goHome: {}) }
