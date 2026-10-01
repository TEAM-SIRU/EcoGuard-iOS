import ImageIO
import UIKit
import UniformTypeIdentifiers

/// 업로드 전 사진 축소·JPEG 압축. 원본을 통째로 디코딩하지 않고 ImageIO 썸네일로 바로 줄인다.
nonisolated enum VerificationPhotoEncoder {
    /// 긴 변 최대 픽셀. AI 검수는 구역 전체가 보이는지와 청소 상태를 보므로 약 2MP(1600 × 1200)면 충분하다.
    /// 12MP 원본을 그대로 올리면 수 MB가 되어, 10분 인증 시간 안에 학교 와이파이·데이터로 올리기 부담스럽다.
    /// 서버 검수 모델의 입력 크기가 정해지면 그 값에 맞춘다.
    static let maxPixelLength: CGFloat = 1600
    /// JPEG 품질. 0.7은 사진 속 글자·물체 윤곽이 뭉개지지 않는 선에서 용량을 줄이는 일반적인 값이다.
    static let jpegQuality: CGFloat = 0.7

    struct Output: Sendable {
        let image: UIImage
        let jpegData: Data
    }

    /// 메인 스레드를 막지 않도록 백그라운드에서 변환한다.
    static func encodeInBackground(_ data: Data) async -> Output? {
        await Task.detached(priority: .userInitiated) {
            encode(data)
        }.value
    }

    /// 긴 변이 `maxPixelLength`를 넘으면 비율을 유지해 줄이고 JPEG로 만든다.
    /// 방향(EXIF Orientation)은 픽셀에 반영하고, EXIF·GPS 등 원본 메타데이터는 옮기지 않는다(촬영 위치 등 개인정보 제거).
    static func encode(_ data: Data) -> Output? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelLength,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else { return nil }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else {
            return nil
        }
        let properties: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: jpegQuality]
        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return Output(image: UIImage(cgImage: cgImage), jpegData: output as Data)
    }
}
