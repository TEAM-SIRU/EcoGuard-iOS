import SwiftUI

/// Figma `02 홈 · 조회 실패` (823:4255) · `활동 제외 안내` (823:4449). 가운데 아이콘·제목·설명.
/// 홈은 루트 화면이라 Figma의 뒤로가기 버튼은 두지 않는다.
struct HomeMessageView: View {
    enum Kind {
        /// 조회 실패. 빨간 아이콘, 설명 아래 24에 폭 200 `다시 시도` 버튼.
        case failed(retry: () async -> Void)
        /// 활동 제외. 회색 아이콘, 하단에 보조 버튼 두 개(`홈으로` · `공지 보기`).
        case excluded(recheck: () async -> Void, openNotices: () -> Void)
    }

    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let kind: Kind

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xxl) {
                EcoMessageContent(icon: .iconAlertHero, iconTint: iconTint, title: title, message: message)
                if case .failed(let retry) = kind {
                    EcoButton("다시 시도", action: retry)
                        .frame(width: Metrics.retryWidth)
                }
            }
            .containerRelativeFrame(.vertical, alignment: .center)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            if case .excluded(let recheck, let openNotices) = kind {
                BottomCTA {
                    VStack(spacing: Spacing.sm) {
                        EcoButton("홈으로", style: .secondary, action: recheck)
                        EcoButton("공지 보기", style: .secondary, action: openNotices)
                    }
                }
            }
        }
    }

    private var iconTint: Color {
        switch kind {
        case .failed: .ecoRejected
        case .excluded: .ecoTextMuted
        }
    }
}

private enum Metrics {
    static let retryWidth: CGFloat = 200
}
