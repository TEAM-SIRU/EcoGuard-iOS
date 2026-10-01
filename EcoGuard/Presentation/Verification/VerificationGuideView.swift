import SwiftUI

/// Figma `06-1 청소 인증 · 촬영 안내` (239:91). 권한 안내 시트(317:295)도 이 화면 위에 뜬다.
struct VerificationGuideView: View {
    let area: String
    let back: () -> Void
    let startCapture: () async -> Void

    var body: some View {
        VStack(spacing: 0) {
            VerificationNavBar(step: "1/3", back: back)
            ScrollView {
                VStack(spacing: 0) {
                    VerificationTitle(title: "이렇게 찍어 주세요", message: "사진 1장으로 오늘 청소를 인증해요")
                    illustration
                    GuideRow(icon: .iconFrame, title: "구역 전체가 보이게 찍어요", subtitle: "복도 끝까지 한 장에 담아 주세요")
                    GuideRow(icon: .iconSun, title: "밝은 곳에서 흔들리지 않게 찍어요", subtitle: "어두우면 반려될 수 있어요")
                    GuideRow(icon: .iconBan, title: "갤러리 사진은 쓸 수 없어요", subtitle: "하루 1번만 제출할 수 있어요")
                }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .safeAreaInset(edge: .bottom) {
            BottomCTA {
                EcoButton("촬영하기", leadingIcon: .iconCam) {
                    await startCapture()
                }
            }
        }
    }

    private var illustration: some View {
        VStack(spacing: Spacing.md) {
            Image(.iconFrameHero)
                .foregroundStyle(Color.ecoPrimary)
                .frame(width: Metrics.illustrationIconFrame, height: Metrics.illustrationIconFrame)
                .accessibilityHidden(true)
            Text(verbatim: area)
                .ecoFont(.body2Medium)
                .foregroundStyle(Color.ecoTextSub)
        }
        .frame(maxWidth: .infinity)
        .frame(height: Metrics.illustrationHeight)
        .background(Color.ecoSurface, in: RoundedRectangle(cornerRadius: Radius.card))
        .padding(.horizontal, Spacing.screenHorizontal)
        .padding(.bottom, Spacing.sm)
    }
}

/// Figma 촬영 안내 `ListRow` (239:112). 공용 `EcoListRow`와 달리 아이콘 타일 없이 22 아이콘만 둔다.
private struct GuideRow: View {
    let icon: ImageResource
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    var body: some View {
        HStack(spacing: Metrics.rowSpacing) {
            Image(icon)
                .foregroundStyle(Color.ecoPrimary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Metrics.rowTextSpacing) {
                Text(title)
                    .ecoFont(.body1)
                    .foregroundStyle(Color.ecoTextPrimary)
                Text(subtitle)
                    .ecoFont(.sub)
                    .foregroundStyle(Color.ecoTextCaption)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, Spacing.screenHorizontal)
        .padding(.vertical, Metrics.rowVerticalPadding)
        .accessibilityElement(children: .combine)
    }
}

private enum Metrics {
    static let illustrationHeight: CGFloat = 180
    static let illustrationIconFrame: CGFloat = 72
    static let rowSpacing: CGFloat = 14
    static let rowTextSpacing: CGFloat = 2
    static let rowVerticalPadding: CGFloat = 14
}
