import SwiftUI

/// Figma `Info table` (823:2403). 흰 카드(테두리 + 그림자), 사방 16, radius 16, 행 사이 10.
/// 왼쪽 라벨(body2 caption 색) · 오른쪽 값(body2Medium).
struct EcoInfoTable: View {
    struct Row {
        let label: LocalizedStringKey
        let value: String
    }

    let rows: [Row]

    var body: some View {
        VStack(spacing: Metrics.rowSpacing) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .firstTextBaseline, spacing: Spacing.md) {
                    Text(row.label)
                        .ecoFont(.body2)
                        .foregroundStyle(Color.ecoTextCaption)
                    Spacer(minLength: 0)
                    Text(row.value)
                        .ecoFont(.body2Medium)
                        .foregroundStyle(Color.ecoTextPrimary)
                        .multilineTextAlignment(.trailing)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(Spacing.lg)
        .ecoCardBackground(cornerRadius: Radius.box)
    }
}

private enum Metrics {
    static let rowSpacing: CGFloat = 10
}

#Preview {
    EcoInfoTable(rows: [
        .init(label: "모집 기간", value: "9월 1일(화) – 9월 4일(금)"),
        .init(label: "모집 인원", value: "반별 최대 6명"),
        .init(label: "활동 시간", value: "매일 08:00 – 08:10")
    ])
    .padding(.horizontal, Spacing.screenHorizontal)
}
