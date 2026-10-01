import SwiftUI

/// Figma `06-4 제출 완료 · AI 검수 중` (317:382).
struct VerificationSubmittedView: View {
    let captured: CameraVerificationViewModel.CapturedPhoto
    let submittedAt: Date
    let area: String?
    let goHome: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    header
                        .padding(.bottom, Spacing.xxxl)
                    VerificationPhotoView(image: captured.image, placeholder: "제출한 사진", height: Metrics.photoHeight)
                        .padding(.bottom, Spacing.xxl)
                    VerificationInfoTable(rows: rows)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .frame(minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .safeAreaInset(edge: .bottom) {
            BottomCTA {
                EcoButton("홈으로", action: goHome)
            }
        }
    }

    private var header: some View {
        VStack(spacing: Spacing.lg) {
            HeroIcon(icon: .iconClockHero, style: .logo, tint: .ecoPendingIcon)
            VStack(spacing: Spacing.sm) {
                Text("사진을 보냈어요")
                    .ecoFont(.title2)
                    .foregroundStyle(Color.ecoTextPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text("AI가 확인하고 있어요. 결과는 홈에서 알려드려요")
                    .ecoFont(.body2)
                    .foregroundStyle(Color.ecoTextSub)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var rows: [VerificationInfoTable.Row] {
        var rows: [VerificationInfoTable.Row] = []
        if let area {
            rows.append(.init(label: "담당 구역", value: area))
        }
        rows.append(.init(label: "제출 시각", value: "오늘 \(HomeFormatter.clockTime(submittedAt))"))
        rows.append(.init(label: "상태", value: "AI 검수 중", valueColor: .ecoPending))
        return rows
    }
}

private enum Metrics {
    static let photoHeight: CGFloat = 200
}
