import SwiftUI

/// Figma `07 활동 기록` (240:3) 합계 + 통계 카드 묶음.
/// 합계: 라벨 body2 · 값 title1, 사이 2, 위 12 · 아래 16. 카드: surface 배경, radius 16, 안쪽 16, 라벨 captionMedium · 값 title2 사이 4, 카드 사이 8, 아래 24.
struct EcoStatSummary: View {
    struct Stat: Identifiable {
        let title: String
        let value: String

        var id: String { title }
    }

    let title: String
    let value: String
    /// 합계가 0보다 크면 초록(green/700), 0이면 본문색(Figma `07 활동 기록 · 빈 상태` 240:116).
    let isHighlighted: Bool
    let stats: [Stat]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: Metrics.totalSpacing) {
                Text(title)
                    .ecoFont(.body2)
                    .foregroundStyle(Color.ecoTextSub)
                Text(value)
                    .ecoFont(.title1)
                    .foregroundStyle(isHighlighted ? Color.ecoPrimaryText : Color.ecoTextPrimary)
            }
            .accessibilityElement(children: .combine)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.lg)
            HStack(spacing: Spacing.sm) {
                ForEach(stats) { stat in
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(stat.title)
                            .ecoFont(.captionMedium)
                            .foregroundStyle(Color.ecoTextCaption)
                        Text(stat.value)
                            .ecoFont(.title2)
                            .foregroundStyle(Color.ecoTextPrimary)
                    }
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Spacing.lg)
                    .background(Color.ecoSurface, in: RoundedRectangle(cornerRadius: Radius.button))
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.bottom, Spacing.xxl)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.screenHorizontal)
    }
}

private enum Metrics {
    static let totalSpacing: CGFloat = 2
}

#Preview {
    VStack(spacing: 0) {
        EcoStatSummary(
            title: "이번 달 활동 시간",
            value: "70분",
            isHighlighted: true,
            stats: [.init(title: "승인", value: "7회"), .init(title: "반려", value: "1회"), .init(title: "미제출", value: "1회")]
        )
        EcoStatSummary(
            title: "이번 달 활동 시간",
            value: "0분",
            isHighlighted: false,
            stats: [.init(title: "승인", value: "0회"), .init(title: "반려", value: "0회"), .init(title: "미제출", value: "0회")]
        )
    }
}
