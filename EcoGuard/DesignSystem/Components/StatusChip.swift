import SwiftUI

/// Figma `Chip/ok` · `Chip/wait` · `Chip/rej` · `Chip/none`.
/// 색맹 대응으로 색 + 아이콘 + 텍스트를 함께 쓴다.
struct StatusChip: View {
    enum Status {
        case approved
        case processing
        case rejected
        // `none`은 Optional.none과 겹쳐 `Status?`에서 모호해지므로 피했다.
        case notSubmitted
    }

    let status: Status

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(status.icon)
                .resizable()
                .frame(width: Metrics.iconSize, height: Metrics.iconSize)
                .foregroundStyle(status.iconColor)
                .accessibilityHidden(true)
            Text(status.title)
                .ecoFont(.caption)
                .foregroundStyle(status.textColor)
                .lineLimit(1)
        }
        .padding(.vertical, Spacing.xs)
        .accessibilityElement(children: .combine)
    }
}

private extension StatusChip {
    enum Metrics {
        static let iconSize: CGFloat = 14
    }
}

private extension StatusChip.Status {
    var title: LocalizedStringKey {
        switch self {
        case .approved: "승인"
        case .processing: "검수 중"
        case .rejected: "반려"
        case .notSubmitted: "미제출"
        }
    }

    var icon: ImageResource {
        switch self {
        case .approved: .iconCheck
        case .processing: .iconClock
        case .rejected: .iconAlert
        case .notSubmitted: .iconCircle
        }
    }

    var textColor: Color {
        switch self {
        case .approved: .ecoPrimaryText
        case .processing: .ecoPending
        case .rejected: .ecoRejected
        case .notSubmitted: .ecoTextSub
        }
    }

    /// 승인만 아이콘(green/500)과 텍스트(green/700) 변수가 다르다.
    var iconColor: Color {
        switch self {
        case .approved: .ecoPrimary
        default: textColor
        }
    }
}

#Preview {
    HStack(spacing: Spacing.sm) {
        StatusChip(status: .approved)
        StatusChip(status: .processing)
        StatusChip(status: .rejected)
        StatusChip(status: .notSubmitted)
    }
}
