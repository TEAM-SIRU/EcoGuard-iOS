import SwiftUI

/// Figma `Bar` (255:592). 높이 8, radius 4.
struct EcoProgressBar: View {
    /// 0...1
    let progress: Double

    var body: some View {
        Capsule()
            .fill(Color.ecoDivider)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(Color.ecoPrimary)
                        .frame(width: proxy.size.width * min(max(progress, 0), 1))
                }
            }
            .frame(height: Metrics.height)
            .accessibilityHidden(true)
    }
}

private enum Metrics {
    static let height: CGFloat = 8
}

#Preview {
    EcoProgressBar(progress: 4.0 / 6.0)
        .padding(Spacing.screenHorizontal)
}
