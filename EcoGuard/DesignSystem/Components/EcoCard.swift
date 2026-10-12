import SwiftUI

/// Figma `02 홈` 흰 카드. 흰색 + 1px grey/200 테두리 + 2단 그림자. 스타일마다 안쪽 여백·라운드가 다르다.
/// - `notice`: `Notice card` (823:870) 위 18 · 좌우 16 · 아래 16
/// - `content`: `Today card` · `Recruit card` 위 18 · 좌우 16 · 아래 16
/// - `plain`: `Week card` 사방 16
/// - `row`: `Record card` 위아래 14 · 좌우 16, radius 16
struct EcoCard<Content: View>: View {
    enum Style {
        case notice
        case content
        case plain
        case row
    }

    private let style: Style
    private let content: Content

    init(_ style: Style, @ViewBuilder content: () -> Content) {
        self.style = style
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(style.insets)
            .ecoCardBackground(cornerRadius: style.cornerRadius)
    }
}

private extension EcoCard.Style {
    var insets: EdgeInsets {
        switch self {
        case .notice, .content:
            EdgeInsets(top: Metrics.contentTop, leading: Spacing.lg, bottom: Spacing.lg, trailing: Spacing.lg)
        case .plain:
            EdgeInsets(top: Spacing.lg, leading: Spacing.lg, bottom: Spacing.lg, trailing: Spacing.lg)
        case .row:
            EdgeInsets(top: Metrics.rowVertical, leading: Spacing.lg, bottom: Metrics.rowVertical, trailing: Spacing.lg)
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .row: Radius.box
        default: Radius.card
        }
    }
}

private enum Metrics {
    static let contentTop: CGFloat = 18
    static let rowVertical: CGFloat = 14
}

#Preview {
    VStack(spacing: Spacing.md) {
        EcoCard(.notice) { Text(verbatim: "notice").ecoFont(.body2) }
        EcoCard(.content) { Text(verbatim: "content").ecoFont(.body2) }
        EcoCard(.plain) { Text(verbatim: "plain").ecoFont(.body2) }
        EcoCard(.row) { Text(verbatim: "row").ecoFont(.body2) }
    }
    .padding(Spacing.screenHorizontal)
    .background(Color.ecoCanvas)
}
