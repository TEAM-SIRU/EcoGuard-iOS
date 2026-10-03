import SwiftUI

/// 화면 가운데 빈 상태·실패 안내. Figma `06 청소구역 · 미배정` (246:152) · `05 청소구역 · 조회 실패` (317:1245).
/// 64 영역 가운데 30 아이콘, 제목 body1Bold, 설명 body2, 선택 버튼(compact). 간격 12.
struct EcoEmptyState: View {
    struct Action {
        let title: LocalizedStringKey
        let perform: () async -> Void
    }

    let icon: ImageResource
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    var action: Action?

    var body: some View {
        VStack(spacing: Spacing.md) {
            Image(icon)
                .resizable()
                .frame(width: Metrics.iconSize, height: Metrics.iconSize)
                .foregroundStyle(Color.ecoDisabled)
                .frame(width: Metrics.iconArea, height: Metrics.iconArea)
                .accessibilityHidden(true)
            VStack(spacing: Spacing.md) {
                Text(title)
                    .ecoFont(.body1Bold)
                    .foregroundStyle(Color.ecoTextPrimary)
                Text(message)
                    .ecoFont(.body2)
                    .foregroundStyle(Color.ecoTextSub)
            }
            .multilineTextAlignment(.center)
            .accessibilityElement(children: .combine)
            if let action {
                EcoButton(action.title, style: .secondary, size: .compact, action: action.perform)
            }
        }
        .padding(.horizontal, Spacing.screenHorizontal)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private enum Metrics {
    static let iconArea: CGFloat = 64
    static let iconSize: CGFloat = 30
}

#Preview {
    EcoEmptyState(
        icon: .iconMapHero,
        title: "도면을 불러오지 못했어요",
        message: "인터넷 연결을 확인하고 다시 시도해 주세요",
        action: .init(title: "다시 시도", perform: {})
    )
}
