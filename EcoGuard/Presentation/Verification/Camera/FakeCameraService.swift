import UIKit

/// 시뮬레이터·Preview·테스트용 카메라. 촬영하면 샘플 이미지를 돌려준다.
final class FakeCameraService: CameraService {
    struct CaptureFailedError: Error {}

    let sampleImage: UIImage
    var shouldFailCapture = false
    private(set) var isRunning = false
    private(set) var captureCount = 0
    private(set) var switchCount = 0

    init(sampleImage: UIImage = FakeCameraService.makeSampleImage()) {
        self.sampleImage = sampleImage
    }

    var previewSource: CameraPreviewSource {
        .image(sampleImage)
    }

    func start() async throws {
        isRunning = true
    }

    func stop() {
        isRunning = false
    }

    func switchPosition() async throws {
        switchCount += 1
    }

    func capturePhoto() async throws -> UIImage {
        captureCount += 1
        if shouldFailCapture {
            throw CaptureFailedError()
        }
        return sampleImage
    }

    /// 복도 모양을 단순하게 그린 샘플 사진(세로 3:4).
    static func makeSampleImage(size: CGSize = CGSize(width: 900, height: 1200)) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cgContext = context.cgContext
            let width = size.width
            let height = size.height
            // 벽
            UIColor(red: 0.84, green: 0.86, blue: 0.85, alpha: 1).setFill()
            cgContext.fill(CGRect(origin: .zero, size: size))
            // 바닥(소실점으로 좁아지는 사다리꼴)
            UIColor(red: 0.62, green: 0.66, blue: 0.64, alpha: 1).setFill()
            let floor = UIBezierPath()
            floor.move(to: CGPoint(x: 0, y: height))
            floor.addLine(to: CGPoint(x: width, y: height))
            floor.addLine(to: CGPoint(x: width * 0.62, y: height * 0.55))
            floor.addLine(to: CGPoint(x: width * 0.38, y: height * 0.55))
            floor.close()
            floor.fill()
            // 복도 끝 창
            UIColor(red: 0.93, green: 0.97, blue: 1, alpha: 1).setFill()
            cgContext.fill(CGRect(x: width * 0.42, y: height * 0.36, width: width * 0.16, height: height * 0.19))
        }
    }
}

/// 테스트·Preview·시뮬레이터용 권한. 요청하면 `grantsOnRequest`대로 답한다.
final class FakeCameraPermission: CameraPermission {
    private(set) var status: CameraAuthorization
    private let grantsOnRequest: Bool
    private(set) var requestCount = 0

    init(status: CameraAuthorization = .authorized, grantsOnRequest: Bool = true) {
        self.status = status
        self.grantsOnRequest = grantsOnRequest
    }

    func requestAccess() async -> Bool {
        requestCount += 1
        status = grantsOnRequest ? .authorized : .denied
        return grantsOnRequest
    }
}
