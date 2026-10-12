import SwiftUI

/// Figma `Notice card` (823:870). 새 공지를 메인에 크게 보여 주고 X로 닫는다.
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
                bodyText
                    .ecoFont(.body2)
                Button(action: onOpen) {
                    HStack(spacing: Metrics.tightSpacing) {
                        Text("자세히 보기")
                            .ecoFont(.body2Bold)
                            .foregroundStyle(Color.ecoPrimaryText)
                        Image(.iconChevronRight)
                            .foregroundStyle(Color.ecoPrimaryIcon)
                            .accessibilityHidden(true)
                    }
                }
                .buttonStyle(.plain)
                .padding(.top, Spacing.md)
            }
        }
    }

    /// 본문(마크다운)이 없으면(서버 목록에서 받은 공지) 미리보기를 마크다운으로 읽지 않고 그대로 보여 준다.
    private var bodyText: Text {
        if notice.body.isEmpty {
            Text(verbatim: notice.preview).foregroundStyle(Color.ecoTextSub)
        } else {
            Text(HomeNoticeBody.attributed(from: notice.body))
        }
    }

    /// Figma 머리 영역: 40 아이콘 타일 · 제목/날짜 · X. Redesign 2에서 NEW 태그는 빠졌다.
    private var header: some View {
        HStack(spacing: Spacing.md) {
            Image(.iconMegaphone)
                .foregroundStyle(Color.ecoPrimaryIcon)
                .padding(Spacing.sm)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Metrics.tightSpacing) {
                Text("환경지킴이 공지")
                    .ecoFont(.body1Bold)
                    .foregroundStyle(Color.ecoTextPrimary)
                Text(HomeFormatter.noticeDate(notice.publishedAt))
                    .ecoFont(.captionRegular)
                    .foregroundStyle(Color.ecoTextCaption)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // 제목·날짜를 따로 읽지 않고 한 번에 읽는다(#92). 새 공지 여부는 값으로 알린다.
            .accessibilityElement(children: .combine)
            .accessibilityValue(notice.isNew ? Text("새 공지") : Text(verbatim: ""))
            EcoIconButton(icon: .iconClose, color: .ecoTextCaption, accessibilityLabel: "공지 닫기", action: onDismiss)
        }
    }
}

private enum Metrics {
    static let tightSpacing: CGFloat = 2
}

#Preview {
    HomeNoticeCard(notice: MockHomeRepository.Fixture.notice, onOpen: {}, onDismiss: {})
        .padding(Spacing.screenHorizontal)
        .background(Color.ecoCanvas)
}
