import SwiftUI

/// 카드 안 안내 상자. px14 py12, radius 12.
/// - `warning`: Figma `Reason` (238:519) 흰 배경 + 테두리, 빨간 제목 + 본문
/// - `note`: Figma `Note` (255:443) 회색 배경 안내 문구
/// - `field`: Figma `09 이의신청` 반려 사유 (239:281) 읽기 전용 입력칸. 회색 배경 body2, px16 py14
struct EcoInfoBox: View {
    enum Style {
        case warning(title: LocalizedStringKey)
        case note
        case field
    }

    let style: Style
    let message: String

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, isField ? Spacing.lg : Metrics.horizontalPadding)
            .padding(.vertical, isField ? Metrics.fieldVerticalPadding : Spacing.md)
            .background(background)
            .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var content: some View {
        switch style {
        case .warning(let title):
            VStack(alignment: .leading, spacing: Metrics.textSpacing) {
                Text(title)
                    .ecoFont(.caption)
                    .foregroundStyle(Color.ecoRejected)
                Text(message)
                    .ecoFont(.body2Medium)
                    .foregroundStyle(Color.ecoTextPrimary)
            }
        case .note:
            Text(message)
                .ecoFont(.sub)
                .foregroundStyle(Color.ecoTextSub)
        case .field:
            Text(message)
                .ecoFont(.body2)
                .foregroundStyle(Color.ecoTextSub)
        }
    }

    private var isField: Bool {
        if case .field = style {
            return true
        }
        return false
    }

    @ViewBuilder
    private var background: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.tile)
        switch style {
        case .warning:
            shape
                .fill(Color.ecoCard)
                .overlay { shape.stroke(Color.ecoBorder) }
        case .note, .field:
            shape.fill(Color.ecoDivider)
        }
    }
}

private enum Metrics {
    static let horizontalPadding: CGFloat = 14
    static let fieldVerticalPadding: CGFloat = 14
    static let textSpacing: CGFloat = 2
}

#Preview {
    VStack(spacing: Spacing.md) {
        EcoInfoBox(style: .warning(title: "반려 사유"), message: "사진에 청소 구역이 잘 보이지 않아요")
        EcoInfoBox(style: .note, message: "AI가 판단하기 어려운 사진이라 선생님께 넘겼어요")
        EcoInfoBox(style: .field, message: "사진에 청소 구역이 잘 보이지 않아요")
    }
    .padding(Spacing.screenHorizontal)
}
