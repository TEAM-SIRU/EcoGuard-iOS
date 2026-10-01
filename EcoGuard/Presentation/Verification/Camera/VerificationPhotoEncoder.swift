import UIKit

/// 업로드 전 사진 축소·JPEG 압축.
enum VerificationPhotoEncoder {
    /// 긴 변 최대 픽셀. AI 검수는 구역 전체가 보이는지와 청소 상태를 보므로 약 2MP(1600 × 1200)면 충분하다.
    /// 12MP 원본을 그대로 올리면 수 MB가 되어, 10분 인증 시간 안에 학교 와이파이·데이터로 올리기 부담스럽다.
    /// 서버 검수 모델의 입력 크기가 정해지면 그 값에 맞춘다.
    static let maxPixelLength: CGFloat = 1600
    /// JPEG 품질. 0.7은 사진 속 글자·물체 윤곽이 뭉개지지 않는 선에서 용량을 줄이는 일반적인 값이다.
    static let jpegQuality: CGFloat = 0.7

    struct Output {
        let image: UIImage
        let jpegData: Data
    }

    /// 긴 변이 `maxPixelLength`를 넘으면 비율을 유지해 줄이고 JPEG로 만든다. 방향(EXIF)은 그리면서 반영한다.
    static func encode(_ image: UIImage) -> Output? {
        let pixelSize = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        let longSide = max(pixelSize.width, pixelSize.height)
        guard longSide > 0 else { return nil }
        let ratio = min(1, maxPixelLength / longSide)
        let targetSize = CGSize(width: (pixelSize.width * ratio).rounded(), height: (pixelSize.height * ratio).rounded())

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let resized = UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        guard let data = resized.jpegData(compressionQuality: jpegQuality) else { return nil }
        return Output(image: resized, jpegData: data)
    }
}
