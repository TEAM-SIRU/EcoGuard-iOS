import SwiftUI

/// 44pt 터치 영역 가운데에 아이콘을 원래 크기로 둔 버튼.
/// Figma `Notice icon · bell · 44pt` (238:196), `Close` (249:14).
struct EcoIconButton: View {
    let icon: ImageResource
    let color: Color
    let accessibilityLabel: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(icon)
                .foregroundStyle(color)
                .frame(width: Metrics.size, height: Metrics.size)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(accessibilityLabel))
    }
}

private enum Metrics {
    static let size: CGFloat = 44
}

#Preview {
    HStack {
        EcoIconButton(icon: .iconBell, color: .ecoTextPrimary, accessibilityLabel: "공지") {}
        EcoIconButton(icon: .iconClose, color: .ecoTextCaption, accessibilityLabel: "공지 닫기") {}
    }
}
