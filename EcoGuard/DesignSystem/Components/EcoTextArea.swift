import SwiftUI

/// 여러 줄 입력. Figma `09 이의신청` Textarea (239:283 · 239:285): 제목·안내 문구·글자 수 grey/600,
/// 테두리 grey/200(포커스 primary · 오류 red), 안쪽 여백 16, 높이 140에서 글자 수는 왼쪽 아래.
/// 오류 문구와 글자 수(`count/maxLength`)는 입력란 안쪽 아래에 둬서 키보드가 올라와도 입력란과 함께 보인다.
/// 글자 수 기준(공백 제외 여부 등)은 부르는 쪽이 `count`로 정한다.
struct EcoTextArea<Field: Hashable>: View {
    let title: LocalizedStringKey
    let prompt: LocalizedStringKey
    @Binding var text: String
    let count: Int
    let maxLength: Int
    /// 있으면 테두리·글자 수를 빨갛게 하고 문구를 보여 준다.
    let errorMessage: LocalizedStringResource?
    let focus: FocusState<Field?>.Binding
    let field: Field

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title)
                .ecoFont(.subMedium)
                .foregroundStyle(Color.ecoTextCaption)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.sm) {
                TextField("", text: $text, prompt: Text(prompt).foregroundStyle(Color.ecoTextCaption), axis: .vertical)
                    .ecoFont(.body2)
                    .foregroundStyle(Color.ecoTextPrimary)
                    .lineLimit(1...Metrics.maxLines)
                    .focused(focus, equals: field)
                    .accessibilityLabel(Text(title))
                    .accessibilityHint(errorMessage.map { Text($0) } ?? Text(verbatim: ""))
                Spacer(minLength: 0)
                footer
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, minHeight: Metrics.minHeight, alignment: .topLeading)
            .background(Color.ecoCard, in: RoundedRectangle(cornerRadius: Radius.tile))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.tile)
                    .stroke(borderColor, lineWidth: isFocused ? Metrics.focusedBorderWidth : Metrics.borderWidth)
            }
            .contentShape(RoundedRectangle(cornerRadius: Radius.tile))
            .onTapGesture {
                focus.wrappedValue = field
            }
        }
    }

    private var footer: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            Text(verbatim: "\(count)/\(maxLength)")
                .foregroundStyle(errorMessage == nil ? Color.ecoTextCaption : Color.ecoRejected)
                .accessibilityLabel(Text("\(maxLength)자 중 \(count)자"))
            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(Color.ecoRejected)
            }
        }
        .ecoFont(.captionRegular)
    }

    private var isFocused: Bool {
        focus.wrappedValue == field
    }

    private var borderColor: Color {
        if errorMessage != nil {
            return .ecoRejected
        }
        return isFocused ? .ecoPrimary : .ecoBorder
    }
}

private enum Metrics {
    /// Figma 239:285 높이. 글이 길어지면 `maxLines`까지 늘어난다.
    static let minHeight: CGFloat = 140
    static let maxLines = 8
    static let borderWidth: CGFloat = 1
    static let focusedBorderWidth: CGFloat = 1.5
}

private struct EcoTextAreaPreview: View {
    @State private var text = ""
    @FocusState private var focus: Int?

    var body: some View {
        VStack(spacing: Spacing.xxl) {
            EcoTextArea(title: "신청 동기", prompt: "환경지킴이로 활동하고 싶은 이유를 적어 주세요", text: $text, count: text.count, maxLength: 200, errorMessage: nil, focus: $focus, field: 0)
            EcoTextArea(title: "신청 동기", prompt: "", text: .constant(String(repeating: "가", count: 201)), count: 201, maxLength: 200, errorMessage: "200자까지 쓸 수 있어요", focus: $focus, field: 1)
        }
        .padding(Spacing.screenHorizontal)
    }
}

#Preview {
    EcoTextAreaPreview()
}
