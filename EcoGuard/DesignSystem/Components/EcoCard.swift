import SwiftUI

/// Figma `02 홈` 흰 카드. 스타일마다 안쪽 여백·라운드·그림자가 다르다.
/// - `notice`: `Notice card` (249:2) 20 / 20 / 18, 그림자 notice
/// - `content`: `Today card` (238:201) · `Recruit card` (255:583) 위 24 · 좌우 20 · 아래 20
/// - `plain`: `Week card` (306:2) 사방 20
/// - `row`: `Record card` (258:6) 위아래 16 · 좌우 20, radius 16
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
            .background {
                // 그림자를 배경 도형에만 줘야 안쪽 글자·버튼에 그림자가 번지지 않는다.
                RoundedRectangle(cornerRadius: style.cornerRadius)
                    .fill(Color.ecoCard)
                    .ecoShadow(style.shadow)
            }
    }
}

private extension EcoCard.Style {
    var insets: EdgeInsets {
        switch self {
        case .notice:
            EdgeInsets(top: Spacing.xl, leading: Spacing.xl, bottom: Metrics.noticeBottom, trailing: Spacing.xl)
        case .content:
            EdgeInsets(top: Spacing.xxl, leading: Spacing.xl, bottom: Spacing.xl, trailing: Spacing.xl)
        case .plain:
            EdgeInsets(top: Spacing.xl, leading: Spacing.xl, bottom: Spacing.xl, trailing: Spacing.xl)
        case .row:
            EdgeInsets(top: Spacing.lg, leading: Spacing.xl, bottom: Spacing.lg, trailing: Spacing.xl)
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .row: Radius.button
        default: Radius.card
        }
    }

    var shadow: EcoShadow {
        switch self {
        case .notice: .notice
        default: .card
        }
    }
}

private enum Metrics {
    static let noticeBottom: CGFloat = 18
}

#Preview {
    VStack(spacing: Spacing.md) {
        EcoCard(.notice) { Text(verbatim: "notice").ecoFont(.body2) }
        EcoCard(.content) { Text(verbatim: "content").ecoFont(.body2) }
        EcoCard(.plain) { Text(verbatim: "plain").ecoFont(.body2) }
        EcoCard(.row) { Text(verbatim: "row").ecoFont(.body2) }
    }
    .padding(Spacing.screenHorizontal)
    .background(Color.ecoSurface)
}
