import SwiftUI

/// 사진 추가 칸. Figma `09 이의신청` `Add photo` (239:291).
/// 88 정사각, grey/100 배경, radius 12, `icon/cam` 24(grey/700) + `촬영 n/최대`(13/18 Medium grey/600), 사이 4.
struct EcoAddPhotoTile: View {
    let count: Int
    let maxCount: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.xs) {
                Image(.iconCamMedium)
                    .foregroundStyle(Color.ecoTextSub)
                    .accessibilityHidden(true)
                Text(verbatim: "촬영 \(count)/\(maxCount)")
                    .ecoFont(.captionMedium)
                    .foregroundStyle(Color.ecoTextCaption)
            }
            .frame(width: Metrics.size, height: Metrics.size)
            .background(Color.ecoDivider, in: RoundedRectangle(cornerRadius: Radius.tile))
            .contentShape(RoundedRectangle(cornerRadius: Radius.tile))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("사진 찍기"))
        .accessibilityValue(Text("\(maxCount)장 중 \(count)장"))
    }
}

/// 찍은 사진 칸. Figma에 첨부 후 모양이 없어 `Add photo`와 같은 크기·라운드에 오른쪽 위 지우기 버튼을 둔다.
struct EcoPhotoThumbnail: View {
    let jpegData: Data
    let remove: () -> Void

    var body: some View {
        thumbnail
            .frame(width: Metrics.size, height: Metrics.size)
            .clipShape(RoundedRectangle(cornerRadius: Radius.tile))
            .overlay(alignment: .topTrailing) {
                Button(action: remove) {
                    Image(.iconClose)
                        .foregroundStyle(Color.ecoTextSub)
                        .frame(width: Metrics.removeBadgeSize, height: Metrics.removeBadgeSize)
                        .background(Color.ecoCard, in: Circle())
                        .overlay { Circle().stroke(Color.ecoBorder) }
                        .padding(Spacing.xs)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("사진 지우기"))
            }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let image = UIImage(data: jpegData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .accessibilityLabel(Text("찍은 사진"))
        } else {
            Color.ecoDivider
                .accessibilityLabel(Text("사진을 불러오지 못했어요"))
        }
    }
}

private enum Metrics {
    static let size: CGFloat = 88
    static let removeBadgeSize: CGFloat = 28
}

#Preview {
    HStack(spacing: Spacing.sm) {
        EcoPhotoThumbnail(jpegData: Data(), remove: {})
        EcoAddPhotoTile(count: 1, maxCount: 3) {}
    }
}
