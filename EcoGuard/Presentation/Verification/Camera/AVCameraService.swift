// AVCaptureSession은 Sendable 표시가 없지만 Apple 문서대로 전용 큐에서 start/stop을 부른다.
@preconcurrency import AVFoundation
import UIKit

/// AVFoundation 카메라. 세션 시작·정지는 메인 스레드를 막지 않도록 전용 큐에서 한다.
final class AVCameraService: CameraService {
    enum CameraError: Error {
        case deviceUnavailable
        case cannotAddInput
        case cannotAddOutput
        case noImageData
    }

    private nonisolated(unsafe) let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "EcoGuard.camera.session")
    private var input: AVCaptureDeviceInput?
    private var position: AVCaptureDevice.Position = .back
    /// 촬영이 끝날 때까지 델리게이트를 붙잡아 둔다. `AVCapturePhotoOutput`은 델리게이트를 약하게 참조한다.
    private var inFlightCaptures: [Int64: PhotoCaptureDelegate] = [:]

    var previewSource: CameraPreviewSource {
        .session(session)
    }

    func start() async throws {
        if input == nil {
            try configure(position: position)
        }
        let session = session
        await withCheckedContinuation { continuation in
            sessionQueue.async {
                if !session.isRunning {
                    session.startRunning()
                }
                continuation.resume()
            }
        }
    }

    func stop() {
        let session = session
        sessionQueue.async {
            if session.isRunning {
                session.stopRunning()
            }
        }
    }

    func switchPosition() async throws {
        try configure(position: position == .back ? .front : .back)
    }

    func capturePhoto() async throws -> UIImage {
        let settings = AVCapturePhotoSettings()
        let uniqueID = settings.uniqueID
        return try await withCheckedThrowingContinuation { continuation in
            let delegate = PhotoCaptureDelegate { [weak self] result in
                Task { @MainActor in
                    self?.inFlightCaptures[uniqueID] = nil
                }
                continuation.resume(with: result)
            }
            inFlightCaptures[uniqueID] = delegate
            photoOutput.capturePhoto(with: settings, delegate: delegate)
        }
    }

    private func configure(position: AVCaptureDevice.Position) throws {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
            throw CameraError.deviceUnavailable
        }
        let newInput = try AVCaptureDeviceInput(device: device)

        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .photo
        if let input {
            session.removeInput(input)
        }
        guard session.canAddInput(newInput) else {
            if let input {
                session.addInput(input)
            }
            throw CameraError.cannotAddInput
        }
        session.addInput(newInput)
        if !session.outputs.contains(photoOutput) {
            guard session.canAddOutput(photoOutput) else { throw CameraError.cannotAddOutput }
            session.addOutput(photoOutput)
        }
        input = newInput
        self.position = position
    }
}

/// `AVCapturePhotoOutput`이 임의의 큐에서 부르므로 액터에 묶지 않는다.
private nonisolated final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (Result<UIImage, Error>) -> Void

    init(completion: @escaping (Result<UIImage, Error>) -> Void) {
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            completion(.failure(error))
            return
        }
        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else {
            completion(.failure(AVCameraService.CameraError.noImageData))
            return
        }
        completion(.success(image))
    }
}
