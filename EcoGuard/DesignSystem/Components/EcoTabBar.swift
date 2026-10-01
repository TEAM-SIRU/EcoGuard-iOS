import SwiftUI

/// Figma `Tab bar` (255:2). 탭 사이 가운데 칸을 비워 두고 그 위에 카메라 버튼을 18pt 띄워 얹는다.
/// 홈 인디케이터가 없는 기기(하단 safe area 0)는 아래 여백을 따로 준다.
struct EcoTabBar<CenterButton: View>: View {
    private let leadingItems: [EcoTabItem]
    private let trailingItems: [EcoTabItem]
    private let centerButton: CenterButton

    @State private var bottomSafeAreaInset: CGFloat = 0

    init(leadingItems: [EcoTabItem], trailingItems: [EcoTabItem], @ViewBuilder centerButton: () -> CenterButton) {
        self.leadingItems = leadingItems
        self.trailingItems = trailingItems
        self.centerButton = centerButton()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(leadingItems) { EcoTabBarButton(item: $0) }
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: 0)
                .accessibilityHidden(true)
            ForEach(trailingItems) { EcoTabBarButton(item: $0) }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.top, Spacing.sm)
        .padding(.bottom, bottomSafeAreaInset > 0 ? 0 : Spacing.sm)
        .overlay(alignment: .top) {
            centerButton
                .offset(y: -Metrics.centerButtonRise)
        }
        .background {
            Rectangle()
                .fill(Color.ecoCard)
                .ecoShadow(.tabBar)
                .ignoresSafeArea(edges: .bottom)
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.safeAreaInsets.bottom
        } action: { inset in
            bottomSafeAreaInset = inset
        }
    }
}

/// 탭 바의 탭 하나.
struct EcoTabItem: Identifiable {
    let id: AnyHashable
    let title: LocalizedStringKey
    let icon: ImageResource
    let isSelected: Bool
    let action: () -> Void
}

private struct EcoTabBarButton: View {
    let item: EcoTabItem

    var body: some View {
        Button(action: item.action) {
            VStack(spacing: Spacing.xs) {
                Image(item.icon)
                    .foregroundStyle(item.isSelected ? Color.ecoPrimary : Color.ecoTextCaption)
                Text(item.title)
                    .ecoFont(item.isSelected ? .caption2Bold : .caption2Medium)
                    .foregroundStyle(item.isSelected ? Color.ecoPrimaryText : Color.ecoTextCaption)
                    .lineLimit(1)
            }
            .padding(.top, Metrics.itemTopPadding)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(item.isSelected ? [.isSelected] : [])
    }
}

private enum Metrics {
    static let centerButtonRise: CGFloat = 18
    static let itemTopPadding: CGFloat = 2
}

#Preview {
    Color.ecoSurface
        .ignoresSafeArea()
        .safeAreaInset(edge: .bottom, spacing: 0) {
            EcoTabBar(
                leadingItems: [
                    .init(id: 0, title: "홈", icon: .iconTabHome, isSelected: true) {},
                    .init(id: 1, title: "구역", icon: .iconTabMap, isSelected: false) {}
                ],
                trailingItems: [
                    .init(id: 2, title: "기록", icon: .iconTabRecords, isSelected: false) {},
                    .init(id: 3, title: "마이페이지", icon: .iconTabMyPage, isSelected: false) {}
                ]
            ) {
                EcoCameraButton {}
            }
        }
}
