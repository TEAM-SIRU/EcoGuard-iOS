import UIKit

/// 시뮬레이터·Preview·테스트용 카메라. 촬영하면 샘플 사진(JPEG)을 돌려준다.
final class FakeCameraService: CameraService {
    struct CaptureFailedError: Error {}
    struct StartFailedError: Error {}

    let sampleImage: UIImage
    let sampleData: Data
    var shouldFailCapture = false
    /// 설정하면 촬영 결과로 이 데이터를 돌려준다. 변환 실패(깨진 데이터) 테스트에 쓴다.
    var capturedDataOverride: Data?
    var shouldFailStart = false
    private(set) var isRunning = false
    private(set) var startCount = 0
    private(set) var captureCount = 0
    private(set) var switchCount = 0
    private var continuation: AsyncStream<CameraEvent>.Continuation?

    init(sampleImage: UIImage? = nil) {
        let image = sampleImage ?? Self.makeSampleImage()
        self.sampleImage = image
        sampleData = image.jpegData(compressionQuality: 0.9) ?? Data()
    }

    var previewSource: CameraPreviewSource {
        .image(sampleImage)
    }

    func events() -> AsyncStream<CameraEvent> {
        continuation?.finish()
        let (stream, continuation) = AsyncStream.makeStream(of: CameraEvent.self)
        self.continuation = continuation
        return stream
    }

    /// 테스트에서 세션 중단·오류를 흉내 낸다.
    func send(_ event: CameraEvent) {
        if event != .interruptionEnded {
            isRunning = false
        } else {
            isRunning = true
        }
        continuation?.yield(event)
    }

    func start() async throws {
        startCount += 1
        if shouldFailStart {
            throw StartFailedError()
        }
        isRunning = true
    }

    func stop() {
        isRunning = false
        continuation?.finish()
    }

    func switchPosition() async throws {
        switchCount += 1
    }

    func capturePhoto() async throws -> Data {
        captureCount += 1
        if shouldFailCapture {
            throw CaptureFailedError()
        }
        return capturedDataOverride ?? sampleData
    }

    /// 복도 모양을 단순하게 그린 샘플 사진(세로 3:4).
    nonisolated static func makeSampleImage(size: CGSize = CGSize(width: 900, height: 1200)) -> UIImage {
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
