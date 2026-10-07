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
                bodyText
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

    /// 본문(마크다운)이 없으면(서버 목록에서 받은 공지) 미리보기를 마크다운으로 읽지 않고 그대로 보여 준다.
    private var bodyText: Text {
        if notice.body.isEmpty {
            Text(verbatim: notice.preview).foregroundStyle(Color.ecoTextSub)
        } else {
            Text(HomeNoticeBody.attributed(from: notice.body))
        }
    }

    /// Figma 머리 영역: 아이콘 · 제목/날짜 · NEW · X.
    /// 좁은 폭(SE 375pt)에서 제목이 두 줄이 되지 않게, 먼저 Figma 간격 그대로 한 줄을 시도하고
    /// 안 맞으면 NEW와 X 사이 간격만 없앤다. X 버튼 44pt 안에 여백이 있어 눈으로 보이는 간격은 남는다.
    private var header: some View {
        ViewThatFits(in: .horizontal) {
            header(trailingSpacing: Spacing.md, isTitleSingleLine: true)
            header(trailingSpacing: 0, isTitleSingleLine: true)
            header(trailingSpacing: 0, isTitleSingleLine: false)
        }
    }

    private func header(trailingSpacing: CGFloat, isTitleSingleLine: Bool) -> some View {
        HStack(spacing: Spacing.md) {
            Image(.iconMegaphone)
                .foregroundStyle(Color.ecoPrimary)
                .padding(Spacing.md)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("환경지킴이 공지")
                    .ecoFont(.body1Bold)
                    .foregroundStyle(Color.ecoTextPrimary)
                    .lineLimit(isTitleSingleLine ? 1 : nil)
                    .fixedSize(horizontal: isTitleSingleLine, vertical: false)
                Text(HomeFormatter.noticeDate(notice.publishedAt))
                    .ecoFont(.captionRegular)
                    .foregroundStyle(Color.ecoTextCaption)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // 제목·날짜·NEW를 따로 세 번 읽지 않고 한 번에 읽는다(#92).
            .accessibilityElement(children: .combine)
            .accessibilityValue(notice.isNew ? Text("새 공지") : Text(verbatim: ""))
            HStack(spacing: trailingSpacing) {
                if notice.isNew {
                    EcoTag(title: "NEW", style: .new)
                        .accessibilityHidden(true)
                }
                EcoIconButton(icon: .iconClose, color: .ecoTextCaption, accessibilityLabel: "공지 닫기", action: onDismiss)
            }
        }
    }
}

#Preview {
    HomeNoticeCard(notice: MockHomeRepository.Fixture.notice, onOpen: {}, onDismiss: {})
        .padding(Spacing.screenHorizontal)
        .background(Color.ecoSurface)
}
