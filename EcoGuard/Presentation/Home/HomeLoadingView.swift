import SwiftUI

/// Figma `02 홈 · 로딩` (514:253).
struct HomeLoadingView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxl) {
            Text("환경지킴이")
                .ecoFont(.title1)
                .foregroundStyle(Color.ecoTextSub)
            EcoSkeleton(kind: .shortLine)
            EcoSkeleton(kind: .card)
            EcoSkeleton(kind: .row)
            EcoSkeleton(kind: .row)
            EcoSkeleton(kind: .longLine)
            Text("불러오는 중이에요")
                .ecoFont(.captionRegular)
                .foregroundStyle(Color.ecoTextSub)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.screenHorizontal)
        .padding(.top, Spacing.xxl)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    HomeLoadingView()
}
