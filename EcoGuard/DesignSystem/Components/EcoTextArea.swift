import SwiftUI

/// 여러 줄 입력. Foundations `12 타일·입력` 라운드, 테두리 grey/200(포커스 primary · 오류 red).
/// 아래에 오류 문구와 글자 수(`count/maxLength`)를 둔다.
struct EcoTextArea<Field: Hashable>: View {
    let title: LocalizedStringKey
    let prompt: LocalizedStringKey
    @Binding var text: String
    let maxLength: Int
    /// 있으면 테두리·글자 수를 빨갛게 하고 문구를 보여 준다.
    let errorMessage: LocalizedStringKey?
    let focus: FocusState<Field?>.Binding
    let field: Field

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title)
                .ecoFont(.subMedium)
                .foregroundStyle(Color.ecoTextSub)
                .accessibilityHidden(true)
            TextField("", text: $text, prompt: Text(prompt).foregroundStyle(Color.ecoDisabled), axis: .vertical)
                .ecoFont(.body2)
                .foregroundStyle(Color.ecoTextPrimary)
                .lineLimit(Metrics.minLines...Metrics.maxLines)
                .focused(focus, equals: field)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
                .background(Color.ecoCard, in: RoundedRectangle(cornerRadius: Radius.tile))
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.tile)
                        .stroke(borderColor, lineWidth: isFocused ? Metrics.focusedBorderWidth : Metrics.borderWidth)
                }
                .accessibilityLabel(Text(title))
                .accessibilityValue(Text(verbatim: text))
                .accessibilityHint(errorMessage.map { Text($0) } ?? Text(verbatim: ""))
            HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(Color.ecoRejected)
                }
                Spacer(minLength: 0)
                Text(verbatim: "\(text.count)/\(maxLength)")
                    .foregroundStyle(errorMessage == nil ? Color.ecoTextCaption : Color.ecoRejected)
                    .accessibilityLabel(Text("\(maxLength)자 중 \(text.count)자"))
            }
            .ecoFont(.captionRegular)
        }
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
    static let minLines = 5
    static let maxLines = 8
    static let borderWidth: CGFloat = 1
    static let focusedBorderWidth: CGFloat = 1.5
}

private struct EcoTextAreaPreview: View {
    @State private var text = ""
    @FocusState private var focus: Int?

    var body: some View {
        VStack(spacing: Spacing.xxl) {
            EcoTextArea(title: "신청 동기", prompt: "환경지킴이로 활동하고 싶은 이유를 적어 주세요", text: $text, maxLength: 200, errorMessage: nil, focus: $focus, field: 0)
            EcoTextArea(title: "신청 동기", prompt: "", text: .constant(String(repeating: "가", count: 201)), maxLength: 200, errorMessage: "200자까지 쓸 수 있어요", focus: $focus, field: 1)
        }
        .padding(Spacing.screenHorizontal)
    }
}

#Preview {
    EcoTextAreaPreview()
}
