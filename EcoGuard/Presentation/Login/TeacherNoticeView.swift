import SwiftUI

/// Figma `01 로그인 · 교사 계정 안내` (309:24). 교사 계정은 앱을 쓰지 않고 로그아웃만 할 수 있다.
struct TeacherNoticeView: View {
    let onLogout: () async -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            VStack(spacing: Spacing.lg) {
                HeroIcon(icon: .iconList, style: .badge)
                VStack(spacing: Spacing.sm) {
                    Text("선생님은 웹에서 이용해 주세요")
                        .ecoFont(.title2)
                        .foregroundStyle(Color.ecoTextPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Text("모집·청소 구역·이의신청 관리는 웹 관리자 페이지에서 할 수 있어요")
                        .ecoFont(.body2)
                        .foregroundStyle(Color.ecoTextSub)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.bottom, Spacing.xxl + Spacing.sm)
            Spacer(minLength: 0)
        }
        .safeAreaInset(edge: .bottom) {
            BottomCTA {
                EcoButton("로그아웃", style: .secondary) {
                    await onLogout()
                }
            }
        }
    }
}

#Preview("교사") {
    TeacherNoticeView {}
}
