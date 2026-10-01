import SwiftUI

/// 청소 인증 화면 상단 바. 뒤로가기 + 단계 표시(1/3 등). Figma `Nav` (239:95).
struct VerificationNavBar: View {
    var step: String?
    let back: () -> Void

    var body: some View {
        HStack {
            EcoIconButton(icon: .iconBack, color: .ecoTextPrimary, accessibilityLabel: "뒤로", action: back)
            Spacer()
            if let step {
                Text(verbatim: step)
                    .ecoFont(.body2Medium)
                    .foregroundStyle(Color.ecoTextCaption)
                    .accessibilityLabel(Text("단계 \(step)"))
            }
        }
        .padding(.leading, Spacing.md)
        .padding(.trailing, Spacing.xl)
        .padding(.vertical, Spacing.xs)
    }
}

/// 제목 + 설명. Figma `Title` (239:100).
struct VerificationTitle: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.titleSpacing) {
            Text(title)
                .ecoFont(.title1)
                .foregroundStyle(Color.ecoTextPrimary)
                .accessibilityAddTraits(.isHeader)
            Text(message)
                .ecoFont(.body2)
                .foregroundStyle(Color.ecoTextSub)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.xl)
        .padding(.horizontal, Spacing.screenHorizontal)
    }
}

/// 찍은 사진. 없으면 Figma 자리표시(icon/image + 문구)를 그린다. Figma `Photo` (239:190).
struct VerificationPhotoView: View {
    let image: UIImage?
    let placeholder: LocalizedStringKey
    let height: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.card)
        ZStack {
            shape.fill(Color.ecoDivider)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                VStack(spacing: Spacing.sm) {
                    Image(.iconPhoto)
                        .foregroundStyle(Color.ecoTextCaption)
                    Text(placeholder)
                        .ecoFont(.sub)
                        .foregroundStyle(Color.ecoTextCaption)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipShape(shape)
        .accessibilityElement()
        .accessibilityLabel(Text(placeholder))
        .accessibilityAddTraits(.isImage)
    }
}

/// 이름·값 표. Figma `Info table` (239:197).
struct VerificationInfoTable: View {
    struct Row: Identifiable {
        let label: LocalizedStringKey
        let value: String
        var valueColor: Color = .ecoTextPrimary

        var id: String { value + "\(label)" }
    }

    let rows: [Row]

    var body: some View {
        VStack(spacing: Spacing.md) {
            ForEach(rows) { row in
                HStack {
                    Text(row.label)
                        .ecoFont(.body2)
                        .foregroundStyle(Color.ecoTextCaption)
                    Spacer()
                    Text(verbatim: row.value)
                        .ecoFont(.body2Medium)
                        .foregroundStyle(row.valueColor)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(Spacing.xl)
        .background(Color.ecoSurface, in: RoundedRectangle(cornerRadius: Radius.button))
    }
}

private enum Metrics {
    static let titleSpacing: CGFloat = 6
}
