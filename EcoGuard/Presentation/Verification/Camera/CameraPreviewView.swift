import AVFoundation
import SwiftUI

/// 카메라 미리보기. 캡처 세션이면 미리보기 레이어를, 샘플 이미지면 이미지를 채워 그린다.
struct CameraPreviewView: View {
    let source: CameraPreviewSource

    var body: some View {
        switch source {
        case .session(let session):
            CaptureSessionPreview(session: session)
        case .image(let image):
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        }
    }
}

private struct CaptureSessionPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewLayerView {
        let view = PreviewLayerView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewLayerView, context: Context) {}

    final class PreviewLayerView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }

        var previewLayer: AVCaptureVideoPreviewLayer {
            // layerClass를 AVCaptureVideoPreviewLayer로 지정했으므로 항상 성공한다.
            layer as? AVCaptureVideoPreviewLayer ?? AVCaptureVideoPreviewLayer()
        }
    }
}
