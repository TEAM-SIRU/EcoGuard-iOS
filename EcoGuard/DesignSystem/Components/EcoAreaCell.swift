import SwiftUI

/// Figma `Floor plan` 칸(239:22 · 239:29 · 239:46). 높이 64, radius 12.
/// 색만으로 구분하지 않도록 이름 앞에 기호(— 청소 안 함, □ 청소 구역)나 핀·"● 내 구역"을 함께 둔다.
struct EcoAreaCell: View {
    enum Style {
        case mine
        case cleaning
        case notCleaning
    }

    let name: String
    let style: Style

    var body: some View {
        content
            .frame(maxWidth: .infinity)
            .frame(height: Metrics.height)
            .background(style.fill, in: RoundedRectangle(cornerRadius: Radius.tile))
            .overlay {
                if let border = style.border {
                    RoundedRectangle(cornerRadius: Radius.tile)
                        .strokeBorder(border.color, lineWidth: border.width)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: "\(name), \(style.accessibilityKind)"))
    }

    @ViewBuilder
    private var content: some View {
        switch style {
        case .mine:
            VStack(spacing: Metrics.mineSpacing) {
                HStack(spacing: Spacing.xs) {
                    Image(.iconPinSmall)
                        .resizable()
                        .frame(width: Metrics.pinSize, height: Metrics.pinSize)
                    Text(verbatim: name)
                        .ecoFont(.body2Bold)
                }
                Text(EcoAreaLegendItem.mineLabel)
                    .ecoFont(.caption)
            }
            .foregroundStyle(Color.ecoPrimaryText)
        case .cleaning, .notCleaning:
            Text(verbatim: "\(style.symbol) \(name)")
                .ecoFont(.sub)
                .foregroundStyle(Color.ecoTextSub)
                .multilineTextAlignment(.center)
        }
    }
}

/// Figma `Legend` (307:105). 14 견본 + 설명.
struct EcoAreaLegendItem: View {
    static let mineLabel = "● 내 구역"

    let style: EcoAreaCell.Style

    var body: some View {
        HStack(spacing: Metrics.legendSpacing) {
            RoundedRectangle(cornerRadius: Metrics.swatchRadius)
                .fill(style.fill)
                .overlay {
                    if let border = style.border {
                        RoundedRectangle(cornerRadius: Metrics.swatchRadius)
                            .strokeBorder(border.color, lineWidth: style == .mine ? Metrics.swatchMineBorder : border.width)
                    }
                }
                .frame(width: Metrics.swatchSize, height: Metrics.swatchSize)
            Text(verbatim: style.legendTitle)
                .ecoFont(.captionMedium)
                .foregroundStyle(style == .notCleaning ? Color.ecoTextSub : Color.ecoTextCaption)
        }
        .accessibilityElement(children: .combine)
    }
}

private extension EcoAreaCell.Style {
    var fill: Color {
        switch self {
        case .mine: .ecoPrimaryTint
        case .cleaning: .ecoCard
        case .notCleaning: .ecoDivider
        }
    }

    var border: (color: Color, width: CGFloat)? {
        switch self {
        case .mine: (.ecoPrimary, Metrics.mineBorder)
        case .cleaning: (.ecoBorderStrong, Metrics.cleaningBorder)
        case .notCleaning: nil
        }
    }

    var symbol: String {
        switch self {
        case .mine: "●"
        case .cleaning: "□"
        case .notCleaning: "—"
        }
    }

    var legendTitle: String {
        switch self {
        case .mine: EcoAreaLegendItem.mineLabel
        case .cleaning: "□ 청소 구역"
        case .notCleaning: "— 청소 안 함"
        }
    }

    var accessibilityKind: String {
        switch self {
        case .mine: "내 구역"
        case .cleaning: "청소 구역"
        case .notCleaning: "청소 안 함"
        }
    }
}

private enum Metrics {
    static let height: CGFloat = 64
    static let mineSpacing: CGFloat = 2
    static let pinSize: CGFloat = 16
    static let mineBorder: CGFloat = 2
    static let cleaningBorder: CGFloat = 1
    static let legendSpacing: CGFloat = 6
    static let swatchSize: CGFloat = 14
    static let swatchRadius: CGFloat = 4
    static let swatchMineBorder: CGFloat = 1.5
}

#Preview {
    VStack(spacing: Spacing.sm) {
        HStack(spacing: Spacing.sm) {
            EcoAreaCell(name: "복도 A", style: .mine)
            EcoAreaCell(name: "계단", style: .notCleaning)
        }
        EcoAreaCell(name: "복도 B", style: .cleaning)
        HStack(spacing: Spacing.lg) {
            EcoAreaLegendItem(style: .mine)
            EcoAreaLegendItem(style: .cleaning)
            EcoAreaLegendItem(style: .notCleaning)
        }
    }
    .padding(Spacing.screenHorizontal)
}
