import SwiftUI

/// Figma `Info table` (246:15). grey/50 배경, 사방 20, radius 16, 행 사이 12.
/// 왼쪽 라벨(body2 caption 색) · 오른쪽 값(body2Medium).
struct EcoInfoTable: View {
    struct Row {
        let label: LocalizedStringKey
        let value: String
    }

    let rows: [Row]

    var body: some View {
        VStack(spacing: Spacing.md) {
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
        .padding(Spacing.xl)
        .background(Color.ecoSurface, in: RoundedRectangle(cornerRadius: Radius.button))
    }
}

#Preview {
    EcoInfoTable(rows: [
        .init(label: "모집 기간", value: "9월 1일(화) – 9월 4일(금)"),
        .init(label: "모집 인원", value: "반별 최대 6명"),
        .init(label: "활동 시간", value: "매일 08:00 – 08:10")
    ])
    .padding(.horizontal, Spacing.screenHorizontal)
}
