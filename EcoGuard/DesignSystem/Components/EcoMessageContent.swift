import SwiftUI

/// Figma 결과·오류 화면 가운데 묶음 (`06-5 업로드 실패` 823:4190 `내용`).
/// 64 아이콘 · 16 · 제목(title2) · 8 · [강조(display) · 8] · 설명(body2), 모두 가운데 정렬.
struct EcoMessageContent: View {
    let icon: ImageResource
    let iconTint: Color
    let title: LocalizedStringKey
    var highlight: String?
    let message: LocalizedStringKey

    var body: some View {
        VStack(spacing: 0) {
            Image(icon)
                .resizable()
                .frame(width: Metrics.iconSize, height: Metrics.iconSize)
                .foregroundStyle(iconTint)
                .accessibilityHidden(true)
                .padding(.bottom, Spacing.lg)
            Text(title)
                .ecoFont(.title2)
                .foregroundStyle(Color.ecoTextPrimary)
                .accessibilityAddTraits(.isHeader)
                .padding(.bottom, Spacing.sm)
            if let highlight {
                Text(verbatim: highlight)
                    .ecoFont(.display)
                    .foregroundStyle(Color.ecoPrimaryText)
                    .padding(.bottom, Spacing.sm)
            }
            Text(message)
                .ecoFont(.body2)
                .foregroundStyle(Color.ecoTextSub)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Spacing.screenHorizontal)
    }
}

private enum Metrics {
    static let iconSize: CGFloat = 64
}

#Preview {
    VStack(spacing: Spacing.xxxl) {
        EcoMessageContent(icon: .iconAlertHero, iconTint: .ecoRejected, title: "사진을 보내지 못했어요", message: "네트워크 연결을 확인하고 다시 시도해 주세요.")
        EcoMessageContent(icon: .iconCheckHero, iconTint: .ecoPrimaryIcon, title: "이의신청이 승인됐어요", highlight: "+10분", message: "선생님이 청소한 내용을 확인했어요.")
    }
    .background(Color.ecoCanvas)
}
