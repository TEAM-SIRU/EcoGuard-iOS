import SwiftUI

/// Figma `Segmented` (239:11). 회색 바탕 안에서 고른 칸만 흰 배경 + Bold.
struct EcoSegmentedControl<ID: Hashable>: View {
    struct Item: Identifiable {
        let id: ID
        let title: String
    }

    let items: [Item]
    let selection: ID?
    let onSelect: (ID) -> Void

    var body: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(items) { item in
                let isSelected = item.id == selection
                Button {
                    onSelect(item.id)
                } label: {
                    Text(item.title)
                        .ecoFont(isSelected ? .body2Bold : .body2Medium)
                        .foregroundStyle(isSelected ? Color.ecoTextPrimary : Color.ecoTextCaption)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.sm)
                        .background(isSelected ? Color.ecoCard : Color.clear, in: RoundedRectangle(cornerRadius: Metrics.itemRadius))
                        .contentShape(RoundedRectangle(cornerRadius: Metrics.itemRadius))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(Spacing.xs)
        .background(Color.ecoDivider, in: RoundedRectangle(cornerRadius: Radius.tile))
    }
}

private enum Metrics {
    static let itemRadius: CGFloat = 10
}

#Preview {
    EcoSegmentedControl(
        items: ["1층", "2층", "3층", "4층"].map { .init(id: $0, title: $0) },
        selection: "2층",
        onSelect: { _ in }
    )
    .padding(Spacing.screenHorizontal)
}
