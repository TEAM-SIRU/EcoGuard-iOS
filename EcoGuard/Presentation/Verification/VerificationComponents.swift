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

extension VerificationPhotoView {
    /// Figma 사진 높이. 반려 `Photo` (309:17) 128 · 결과 (309:3) 200 · 상세 (317:456) 256.
    enum Height {
        static let compact: CGFloat = 128
        static let regular: CGFloat = 200
        static let large: CGFloat = 256
    }
}

/// AI 검수 결과(반려 사유). Figma `AI 검수 결과` (239:258). grey/50 배경, 사방 20, radius 16, 줄 사이 6.
struct VerificationReviewNote: View {
    let title: String
    let guide: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.titleSpacing) {
            Text("AI 검수 결과")
                .ecoFont(.caption)
                .foregroundStyle(Color.ecoTextCaption)
            Text(verbatim: title)
                .ecoFont(.body1Bold)
                .foregroundStyle(Color.ecoTextPrimary)
            if let guide {
                Text(verbatim: guide)
                    .ecoFont(.body2)
                    .foregroundStyle(Color.ecoTextSub)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.xl)
        // Figma 16은 Foundations `버튼·박스` 라운드라 카드(20)가 아닌 `Radius.button`을 쓴다.
        .background(Color.ecoSurface, in: RoundedRectangle(cornerRadius: Radius.button))
        .accessibilityElement(children: .combine)
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
        // Figma `Info table` radius 16은 Foundations `버튼·박스` 라운드라 `Radius.button`을 쓴다.
        .background(Color.ecoSurface, in: RoundedRectangle(cornerRadius: Radius.button))
    }
}

private enum Metrics {
    static let titleSpacing: CGFloat = 6
}
