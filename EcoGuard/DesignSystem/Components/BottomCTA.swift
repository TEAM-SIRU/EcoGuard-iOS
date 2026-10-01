import SwiftUI

/// Figma `Bottom CTA` (238:137). 화면 하단 버튼 영역.
/// Figma 하단 34는 홈 인디케이터 영역이라 `.safeAreaInset(edge: .bottom)`에 넣어 safe area로 처리한다.
/// 하단 safe area가 0인 기기(홈 버튼 기기)에서는 버튼이 화면 끝에 붙지 않도록 최소 여백을 준다.
struct BottomCTA<Content: View>: View {
    private let caption: LocalizedStringKey?
    private let content: Content

    @State private var bottomSafeAreaInset: CGFloat = 0

    init(caption: LocalizedStringKey? = nil, @ViewBuilder content: () -> Content) {
        self.caption = caption
        self.content = content()
    }

    var body: some View {
        VStack(spacing: Metrics.spacing) {
            content
            if let caption {
                Text(caption)
                    .ecoFont(.captionRegular)
                    .foregroundStyle(Color.ecoTextCaption)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, Spacing.md)
        .padding(.horizontal, Spacing.screenHorizontal)
        .padding(.bottom, bottomSafeAreaInset > 0 ? 0 : Spacing.xl)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.safeAreaInsets.bottom
        } action: { inset in
            bottomSafeAreaInset = inset
        }
    }
}

private enum Metrics {
    static let spacing: CGFloat = 10
}

#Preview {
    Color.ecoSurface
        .ignoresSafeArea()
        .safeAreaInset(edge: .bottom) {
            BottomCTA(caption: "학교 계정으로만 로그인할 수 있어요") {
                EcoButton("DataGSM으로 로그인") {}
            }
        }
}
