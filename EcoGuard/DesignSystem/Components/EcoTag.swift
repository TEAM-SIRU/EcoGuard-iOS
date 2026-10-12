import SwiftUI

/// 작은 글자 태그. Figma `신청 완료` (823:3025) 연한 초록 배경, px6 py2 r6.
struct EcoTag: View {
    let title: LocalizedStringKey

    var body: some View {
        Text(title)
            .ecoFont(.caption)
            .foregroundStyle(Color.ecoPrimaryText)
            .lineLimit(1)
            .padding(.horizontal, Metrics.horizontalPadding)
            .padding(.vertical, Metrics.verticalPadding)
            .background(Color.ecoPrimaryTint, in: RoundedRectangle(cornerRadius: Radius.tag))
    }
}

private enum Metrics {
    static let horizontalPadding: CGFloat = 6
    static let verticalPadding: CGFloat = 2
}

#Preview {
    EcoTag(title: "신청 완료")
}
