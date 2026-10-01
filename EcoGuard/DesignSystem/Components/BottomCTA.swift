import SwiftUI

/// Figma `Bottom CTA` (238:137). 화면 하단 버튼 영역.
/// Figma 하단 34는 홈 인디케이터 영역이라 `.safeAreaInset(edge: .bottom)`에 넣어 safe area로 처리한다.
struct BottomCTA<Content: View>: View {
    private let caption: LocalizedStringKey?
    private let content: Content

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
