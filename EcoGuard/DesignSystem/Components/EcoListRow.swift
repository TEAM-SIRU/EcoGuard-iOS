import SwiftUI

/// Figma `ListRow`. 아이콘 타일 + 본문(body1) + 보조(sub) + 오른쪽 액세서리.
/// 모집 공고 안내 행(246:33)처럼 아이콘 없이 화면 좌우 여백에 맞출 때는 `icon: nil`, `horizontalPadding: Spacing.screenHorizontal`.
struct EcoListRow<Accessory: View>: View {
    private let icon: ImageResource?
    private let title: String
    private let subtitle: String?
    private let horizontalPadding: CGFloat
    private let accessory: Accessory

    init(
        icon: ImageResource?,
        title: String,
        subtitle: String? = nil,
        horizontalPadding: CGFloat = Spacing.lg,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.horizontalPadding = horizontalPadding
        self.accessory = accessory()
    }

    var body: some View {
        HStack(spacing: Metrics.spacing) {
            if let icon {
                IconTile(icon: icon)
            }
            VStack(alignment: .leading, spacing: Metrics.textSpacing) {
                Text(title)
                    .ecoFont(.body1)
                    .foregroundStyle(Color.ecoTextPrimary)
                if let subtitle {
                    Text(subtitle)
                        .ecoFont(.sub)
                        .foregroundStyle(Color.ecoTextCaption)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            accessory
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, Metrics.verticalPadding)
        .accessibilityElement(children: .combine)
    }
}

extension EcoListRow where Accessory == EmptyView {
    init(icon: ImageResource?, title: String, subtitle: String? = nil, horizontalPadding: CGFloat = Spacing.lg) {
        self.init(icon: icon, title: title, subtitle: subtitle, horizontalPadding: horizontalPadding) { EmptyView() }
    }
}

private enum Metrics {
    static let spacing: CGFloat = 14
    static let verticalPadding: CGFloat = 14
    static let textSpacing: CGFloat = 2
}

#Preview {
    VStack(spacing: 0) {
        EcoListRow(icon: .iconPin, title: "본관 2층 복도 A", subtitle: "9월 26일 금 · 08:04") {
            StatusChip(status: .approved)
        }
        EcoListRow(icon: .iconPin, title: "본관 3층 계단")
    }
    .overlay {
        RoundedRectangle(cornerRadius: Radius.button)
            .stroke(Color.ecoBorder)
    }
    .padding(.horizontal, Spacing.screenHorizontal)
}
