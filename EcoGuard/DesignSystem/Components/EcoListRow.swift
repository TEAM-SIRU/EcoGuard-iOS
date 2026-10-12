import SwiftUI

/// Figma `ListRow`. 아이콘 타일 + 본문(body1) + 보조(sub) + 오른쪽 액세서리. 위아래 12 · 좌우 16.
/// 화면에서는 `EcoListCard`로 묶어 흰 리스트 카드 안에 둔다.
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

/// `EcoListRow` 오른쪽 이동 표시. 보조 값(선택) + `icon/chev` 20. Figma `12 마이페이지` 메뉴 행(823:2077).
struct EcoListRowDisclosure: View {
    private let value: String?

    init(value: String? = nil) {
        self.value = value
    }

    var body: some View {
        HStack(spacing: Metrics.spacing) {
            if let value {
                Text(value)
                    .ecoFont(.body2Medium)
                    .foregroundStyle(Color.ecoTextCaption)
                    .lineLimit(1)
            }
            Image(.iconChevronRightLarge)
                .foregroundStyle(Color.ecoChevron)
                .accessibilityHidden(true)
        }
    }
}

/// 켜고 끄는 `ListRow`. Figma `12 마이페이지` 청소 알림 행(823:2077). 스위치는 시스템 `Toggle`을 primary 색으로 쓴다.
struct EcoToggleRow: View {
    private let title: String
    @Binding private var isOn: Bool
    private let horizontalPadding: CGFloat

    init(title: String, isOn: Binding<Bool>, horizontalPadding: CGFloat = Spacing.lg) {
        self.title = title
        _isOn = isOn
        self.horizontalPadding = horizontalPadding
    }

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(title)
                .ecoFont(.body1)
                .foregroundStyle(Color.ecoTextPrimary)
        }
        .tint(Color.ecoPrimary)
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, Metrics.verticalPadding)
    }
}

/// Figma `List group` › `List card`. 흰 리스트 카드(radius 24, 위아래 4)에 행을 묶는다. 화면 좌우 16 · 위아래 4.
struct EcoListCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .padding(.vertical, Spacing.xs)
        .ecoCardBackground(cornerRadius: Radius.listCard)
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.xs)
    }
}

private enum Metrics {
    static let spacing: CGFloat = 14
    static let verticalPadding: CGFloat = 12
    static let textSpacing: CGFloat = 2
}

#Preview {
    EcoListCard {
        EcoListRow(icon: .iconPin, title: "본관 2층 복도 A", subtitle: "9월 26일 금 · 08:04") {
            StatusChip(status: .approved)
        }
        EcoListRow(icon: .iconPin, title: "본관 3층 계단")
        EcoListRow(icon: nil, title: "내 청소 구역") {
            EcoListRowDisclosure(value: "본관 2층 복도 A")
        }
        EcoToggleRow(title: "청소 알림", isOn: .constant(true))
    }
    .frame(maxHeight: .infinity)
    .background(Color.ecoCanvas)
}
