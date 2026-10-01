import SwiftUI

/// 토큰 확인용 Preview 전용 화면.
private struct DesignTokenPreview: View {
    private let colors: [(name: String, color: Color)] = [
        ("ecoPrimary", .ecoPrimary),
        ("ecoPrimaryTint", .ecoPrimaryTint),
        ("ecoPrimaryText", .ecoPrimaryText),
        ("ecoTextPrimary", .ecoTextPrimary),
        ("ecoTextSub", .ecoTextSub),
        ("ecoTextCaption", .ecoTextCaption),
        ("ecoDisabled", .ecoDisabled),
        ("ecoBorder", .ecoBorder),
        ("ecoDivider", .ecoDivider),
        ("ecoSurface", .ecoSurface),
        ("ecoRejected", .ecoRejected),
        ("ecoPending", .ecoPending),
        ("ecoPendingIcon", .ecoPendingIcon),
        ("ecoOnPrimary", .ecoOnPrimary)
    ]

    private let radii: [(name: String, value: CGFloat)] = [
        ("tag", Radius.tag),
        ("tile", Radius.tile),
        ("button", Radius.button),
        ("card", Radius.card),
        ("chip", Radius.chip)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xxl) {
                textStyleSection
                colorSection
                radiusSection
            }
            .padding(.horizontal, Spacing.screenHorizontal)
        }
        .background(Color.ecoSurface)
    }

    private var textStyleSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ForEach(EcoTextStyle.allCases, id: \.self) { style in
                Text(verbatim: "\(style) 환경지킴이\n두 번째 줄")
                    .ecoFont(style)
                    .foregroundStyle(Color.ecoTextPrimary)
            }
        }
    }

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            ForEach(colors, id: \.name) { item in
                HStack(spacing: Spacing.md) {
                    RoundedRectangle(cornerRadius: Radius.tag)
                        .fill(item.color)
                        .frame(width: Spacing.xxl, height: Spacing.xxl)
                        .overlay {
                            RoundedRectangle(cornerRadius: Radius.tag)
                                .stroke(Color.ecoBorder)
                        }
                    Text(verbatim: item.name)
                        .ecoFont(.sub)
                        .foregroundStyle(Color.ecoTextSub)
                }
            }
        }
    }

    private var radiusSection: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(radii, id: \.name) { item in
                RoundedRectangle(cornerRadius: item.value)
                    .fill(Color.ecoPrimaryTint)
                    .frame(height: Spacing.xxl * 2)
                    .overlay {
                        Text(verbatim: item.name)
                            .ecoFont(.caption)
                            .foregroundStyle(Color.ecoPrimaryText)
                    }
            }
        }
    }
}

#Preview {
    DesignTokenPreview()
}
