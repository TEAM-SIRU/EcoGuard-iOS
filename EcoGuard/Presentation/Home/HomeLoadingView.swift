import SwiftUI

/// Figma `02 홈 · 로딩` (514:253). 제목 줄은 `HomeView`가 불러온 홈과 같은 상단 바로 얹는다.
struct HomeLoadingView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxl) {
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
        // 불러온 홈의 첫 카드와 같은 자리에서 시작한다.
        .padding(.top, Spacing.sm)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    HomeLoadingView()
}
