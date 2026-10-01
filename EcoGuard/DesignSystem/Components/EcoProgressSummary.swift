import SwiftUI

/// Figma `Progress` (246:25). 제목·값(body1Bold) 한 줄 + 막대 + 안내(sub), 사이 10.
struct EcoProgressSummary: View {
    let title: String
    let value: String
    /// VoiceOver가 "4/6명" 대신 읽을 문장.
    let valueAccessibilityLabel: String
    let progress: Double
    let caption: String
    /// 진행 중이면 초록(값 green/700 · 막대 green/500), 마감이면 caption 회색(Figma 313:36 · 313:38).
    var isActive = true

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spacing) {
            HStack {
                Text(title)
                    .foregroundStyle(Color.ecoTextPrimary)
                Spacer(minLength: Spacing.md)
                Text(value)
                    .foregroundStyle(isActive ? Color.ecoPrimaryText : Color.ecoTextCaption)
                    .accessibilityLabel(Text(valueAccessibilityLabel))
            }
            .ecoFont(.body1Bold)
            .accessibilityElement(children: .combine)
            EcoProgressBar(progress: progress, tint: isActive ? .ecoPrimary : .ecoTextCaption)
            Text(caption)
                .ecoFont(.sub)
                .foregroundStyle(Color.ecoTextCaption)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private enum Metrics {
    static let spacing: CGFloat = 10
}

#Preview {
    VStack(spacing: Spacing.xxl) {
        EcoProgressSummary(
            title: "2학년 3반 신청 현황",
            value: "4/6명",
            valueAccessibilityLabel: "6명 중 4명 신청",
            progress: 4.0 / 6.0,
            caption: "2자리 남았어요. 자리가 차면 바로 마감돼요"
        )
        EcoProgressSummary(
            title: "2학년 3반 신청 현황",
            value: "6/6명",
            valueAccessibilityLabel: "6명 중 6명 신청",
            progress: 1,
            caption: "2학년 3반은 자리가 모두 찼어요. 다음 모집을 기다려 주세요",
            isActive: false
        )
    }
    .padding(Spacing.screenHorizontal)
}
