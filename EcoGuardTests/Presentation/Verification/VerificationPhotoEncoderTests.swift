import ImageIO
import Testing
import UIKit
import UniformTypeIdentifiers
@testable import EcoGuard

struct VerificationPhotoEncoderTests {
    /// 픽셀 `width × height` JPEG에 EXIF·GPS·방향 메타데이터를 붙인다.
    private func jpeg(width: CGFloat, height: CGFloat, orientation: CGImagePropertyOrientation = .up) throws -> Data {
        let image = FakeCameraService.makeSampleImage(size: CGSize(width: width, height: height))
        let cgImage = try #require(image.cgImage)
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil))
        let properties: [CFString: Any] = [
            kCGImagePropertyOrientation: orientation.rawValue,
            kCGImagePropertyExifDictionary: [kCGImagePropertyExifUserComment: "원본 메모"],
            kCGImagePropertyGPSDictionary: [
                kCGImagePropertyGPSLatitude: 37.5,
                kCGImagePropertyGPSLatitudeRef: "N",
                kCGImagePropertyGPSLongitude: 127.0,
                kCGImagePropertyGPSLongitudeRef: "E"
            ]
        ]
        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }

    private func properties(_ data: Data) throws -> [CFString: Any] {
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        return try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
    }

    @Test func shrinksLongSideToLimit() throws {
        let output = try #require(VerificationPhotoEncoder.encode(try jpeg(width: 3024, height: 4032)))

        #expect(output.image.size == CGSize(width: 1200, height: 1600))
        let properties = try properties(output.jpegData)
        #expect(properties[kCGImagePropertyPixelWidth] as? Int == 1200)
        #expect(properties[kCGImagePropertyPixelHeight] as? Int == 1600)
    }

    @Test func keepsSmallImageSize() throws {
        let output = try #require(VerificationPhotoEncoder.encode(try jpeg(width: 300, height: 400)))

        #expect(output.image.size == CGSize(width: 300, height: 400))
    }

    @Test func removesGPSAndExifMetadata() throws {
        let source = try jpeg(width: 300, height: 400)
        // 원본에는 메타데이터가 들어 있다.
        let original = try properties(source)
        #expect(original[kCGImagePropertyGPSDictionary] != nil)

        let output = try #require(VerificationPhotoEncoder.encode(source))
        let encoded = try properties(output.jpegData)

        #expect(encoded[kCGImagePropertyGPSDictionary] == nil)
        let exif = encoded[kCGImagePropertyExifDictionary] as? [CFString: Any]
        #expect(exif?[kCGImagePropertyExifUserComment] == nil)
    }

    @Test func appliesOrientationToPixels() throws {
        // 가로 400 × 세로 300 픽셀을 90도 돌려 보라는 방향(.right) 표시 → 결과는 세로 사진이어야 한다.
        let output = try #require(VerificationPhotoEncoder.encode(try jpeg(width: 400, height: 300, orientation: .right)))
        let encoded = try properties(output.jpegData)

        #expect(encoded[kCGImagePropertyPixelWidth] as? Int == 300)
        #expect(encoded[kCGImagePropertyPixelHeight] as? Int == 400)
        let orientation = encoded[kCGImagePropertyOrientation] as? UInt32
        #expect(orientation == nil || orientation == CGImagePropertyOrientation.up.rawValue)
    }

    @Test func rejectsUndecodableData() {
        #expect(VerificationPhotoEncoder.encode(Data("not an image".utf8)) == nil)
    }
}
