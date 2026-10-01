import SwiftUI

/// Figma `Tile`. 44 정사각 타일 가운데에 22 아이콘을 둔다.
struct IconTile: View {
    let icon: ImageResource

    var body: some View {
        Image(icon)
            .resizable()
            .frame(width: Metrics.iconSize, height: Metrics.iconSize)
            .foregroundStyle(Color.ecoTextSub)
            .frame(width: Metrics.size, height: Metrics.size)
            .background(Color.ecoDivider, in: RoundedRectangle(cornerRadius: Radius.tile))
            .accessibilityHidden(true)
    }
}

private extension IconTile {
    enum Metrics {
        static let size: CGFloat = 44
        static let iconSize: CGFloat = 22
    }
}

#Preview {
    IconTile(icon: .iconPin)
}
