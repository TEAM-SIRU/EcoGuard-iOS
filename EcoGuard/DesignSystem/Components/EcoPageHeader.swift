import SwiftUI

/// Figma 화면 상단 `Title` (246:11 · 309:190). title1 제목 + body2 설명, 사이 6, 아래 20.
/// 위쪽 여백은 화면마다 달라(모집 공고 16 · 신청 8) 부르는 쪽에서 준다.
struct EcoPageHeader: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spacing) {
            Text(title)
                .ecoFont(.title1)
                .foregroundStyle(Color.ecoTextPrimary)
                .accessibilityAddTraits(.isHeader)
            Text(subtitle)
                .ecoFont(.body2)
                .foregroundStyle(Color.ecoTextSub)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.screenHorizontal)
        .padding(.bottom, Spacing.xl)
    }
}

private enum Metrics {
    static let spacing: CGFloat = 6
}

#Preview {
    EcoPageHeader(title: "2학기 환경지킴이를 모집해요", subtitle: "반마다 최대 6명, 먼저 신청한 순서대로 확정돼요")
}
