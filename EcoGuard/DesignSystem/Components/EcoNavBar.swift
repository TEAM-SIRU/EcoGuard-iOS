import SwiftUI

/// Figma `Nav` (309:186). 왼쪽 12, 위아래 4, 44pt 뒤로가기 버튼.
/// 시스템 내비게이션 바 대신 쓴다(iOS 26 툴바 버튼의 유리 배경을 피하고 Figma 위치에 맞춘다).
struct EcoNavBar: View {
    let onBack: () -> Void

    var body: some View {
        HStack {
            EcoIconButton(icon: .iconBack, color: .ecoTextPrimary, accessibilityLabel: "뒤로", action: onBack)
            Spacer(minLength: 0)
        }
        .padding(.leading, Spacing.md)
        .padding(.vertical, Spacing.xs)
    }
}

#Preview {
    EcoNavBar {}
}
