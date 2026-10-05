import SwiftUI

/// Figma `06-2 청소 인증 · 촬영` (239:150). 구역 이름과 단계, 인증 마감 카운트다운을 얹는다.
struct VerificationCaptureView: View {
    let viewModel: CameraVerificationViewModel

    var body: some View {
        CameraCaptureScreen(
            capture: viewModel.capture,
            title: Text(verbatim: viewModel.session?.area ?? ""),
            subtitle: "2/3 · 촬영",
            canTakePhoto: viewModel.canTakePhoto,
            close: viewModel.cancelCapture,
            takePhoto: viewModel.takePhoto
        ) {
            if let deadline = viewModel.deadline {
                DeadlineCountdownBar(
                    deadline: deadline,
                    endMinute: viewModel.session?.window.endMinute,
                    serverDate: viewModel.serverDate(fromDevice:)
                )
            }
        }
    }
}

/// Figma `인증 마감 카운트다운` (512:179). 남은 시간은 서버 마감 시각까지를 1초마다 다시 그린다.
private struct DeadlineCountdownBar: View {
    let deadline: Date
    let endMinute: Int?
    /// 기기 시각 → 서버 시각. 기기 시계가 틀려도 서버 기준 남은 시간을 보여 준다.
    let serverDate: (Date) -> Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(label(now: context.date))
                .ecoFont(.body2)
                .foregroundStyle(Color.ecoOnPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: Metrics.countdownHeight)
                .background(Color.ecoPrimary)
        }
    }

    private func label(now: Date) -> String {
        let remaining = HomeFormatter.countdown(deadline.timeIntervalSince(serverDate(now)))
        guard let endMinute else { return "남은 시간 \(remaining)" }
        return "남은 시간 \(remaining) · \(HomeFormatter.time(minuteOfDay: endMinute)) 마감"
    }
}

private enum Metrics {
    static let countdownHeight: CGFloat = 40
}
