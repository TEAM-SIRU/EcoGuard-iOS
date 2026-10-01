import SwiftUI

/// Figma `Notice card` (249:2). 새 공지를 메인에 크게 보여 주고 X로 닫는다.
struct HomeNoticeCard: View {
    let notice: Notice
    let onOpen: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        EcoCard(.notice) {
            VStack(alignment: .leading, spacing: 0) {
                header
                Text(notice.title)
                    .ecoFont(.title3)
                    .foregroundStyle(Color.ecoTextPrimary)
                    .padding(.top, Spacing.lg)
                    .padding(.bottom, Spacing.sm)
                    .accessibilityAddTraits(.isHeader)
                Text(HomeNoticeBody.attributed(from: notice.body))
                    .ecoFont(.body2)
                Button(action: onOpen) {
                    HStack(spacing: Spacing.xs) {
                        Text("자세히 보기")
                            .ecoFont(.body2Bold)
                        Image(.iconChevronRight)
                            .accessibilityHidden(true)
                    }
                    .foregroundStyle(Color.ecoPrimaryText)
                }
                .buttonStyle(.plain)
                .padding(.top, Spacing.md)
            }
        }
    }

    private var header: some View {
        HStack(spacing: Spacing.md) {
            Image(.iconMegaphone)
                .foregroundStyle(Color.ecoPrimary)
                .padding(Spacing.md)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("환경지킴이 공지")
                    .ecoFont(.body1Bold)
                    .foregroundStyle(Color.ecoTextPrimary)
                Text(HomeFormatter.noticeDate(notice.publishedAt))
                    .ecoFont(.captionRegular)
                    .foregroundStyle(Color.ecoTextCaption)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if notice.isNew {
                EcoTag(title: "NEW", style: .new)
            }
            EcoIconButton(icon: .iconClose, color: .ecoTextCaption, accessibilityLabel: "공지 닫기", action: onDismiss)
        }
    }
}

#Preview {
    HomeNoticeCard(notice: MockHomeRepository.Fixture.notice, onOpen: {}, onDismiss: {})
        .padding(Spacing.screenHorizontal)
        .background(Color.ecoSurface)
}
