import SwiftUI

/// Figma `07 활동 기록 · 월 변경 팝업` (504:173) 월 선택 카드. 월 항목은 `Month/Default` · `Month/Selected` (504:185).
/// 폭 342, 안쪽 여백·간격 24. radius는 Figma 변수(24) 대신 프로젝트 카드 라운드(`Radius.card`)를 쓴다.
/// `range` 밖의 달과 연도는 고를 수 없다. 화면 위에 띄울 때는 `.ecoMonthPicker(isPresented:...)`를 쓴다.
/// 연도·달 문구는 화면의 다른 월 문구와 같은 곳에서 만들도록 `yearTitle` · `monthTitle`로 받는다.
struct EcoMonthPickerDialog: View {
    let range: ClosedRange<YearMonth>
    let yearTitle: (Int) -> String
    let monthTitle: (YearMonth) -> String
    let onApply: (YearMonth) -> Void
    let onCancel: () -> Void

    @State private var year: Int
    @State private var draft: YearMonth

    init(
        selection: YearMonth,
        range: ClosedRange<YearMonth>,
        yearTitle: @escaping (Int) -> String,
        monthTitle: @escaping (YearMonth) -> String,
        onApply: @escaping (YearMonth) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.range = range
        self.yearTitle = yearTitle
        self.monthTitle = monthTitle
        self.onApply = onApply
        self.onCancel = onCancel
        _year = State(initialValue: selection.year)
        _draft = State(initialValue: selection)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxl) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("월 선택")
                    .ecoFont(.title3)
                    .foregroundStyle(Color.ecoTextPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text("조회할 활동 기록의 월을 선택해 주세요.")
                    .ecoFont(.captionRegular)
                    .foregroundStyle(Color.ecoTextCaption)
            }
            yearRow
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.sm), count: Metrics.columns), spacing: Spacing.sm) {
                ForEach(1...12, id: \.self) { month in
                    monthCell(YearMonth(year: year, month: month))
                }
            }
            HStack(spacing: Spacing.sm) {
                actionButton("취소", background: .ecoDivider, foreground: .ecoTextPrimary, action: onCancel)
                // 다른 연도로 넘겨 그 연도에서 아직 달을 고르지 않았으면 적용할 수 없다.
                actionButton(
                    "적용",
                    background: canApply ? .ecoPrimary : .ecoDivider,
                    foreground: canApply ? .ecoOnPrimary : .ecoDisabled
                ) { onApply(draft) }
                .disabled(!canApply)
            }
        }
        .padding(Spacing.xxl)
        .frame(maxWidth: Metrics.width)
        .background(Color.ecoCard, in: RoundedRectangle(cornerRadius: Radius.card))
    }

    private var canApply: Bool {
        draft.year == year
    }

    private var yearRow: some View {
        HStack(spacing: Spacing.sm) {
            yearButton(icon: .iconPagePrevious, label: "이전 연도", target: year - 1)
            Text(yearTitle(year))
                .ecoFont(.title4)
                .foregroundStyle(Color.ecoTextPrimary)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isHeader)
            yearButton(icon: .iconPageNext, label: "다음 연도", target: year + 1)
        }
    }

    private func yearButton(icon: ImageResource, label: LocalizedStringKey, target: Int) -> some View {
        let isEnabled = (range.lowerBound.year...range.upperBound.year).contains(target)
        return Button { year = target } label: {
            Image(icon)
                .foregroundStyle(isEnabled ? Color.ecoTextPrimary : Color.ecoDisabled)
                .frame(width: Metrics.yearButtonSize, height: Metrics.yearButtonSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(PassthroughButtonStyle())
        .disabled(!isEnabled)
        .accessibilityLabel(Text(label))
    }

    private func monthCell(_ month: YearMonth) -> some View {
        let isSelected = month == draft
        let isEnabled = range.contains(month)
        return Button { draft = month } label: {
            Text(monthTitle(month))
                .ecoFont(.title5)
                .foregroundStyle(isSelected ? Color.ecoOnPrimary : isEnabled ? Color.ecoTextPrimary : Color.ecoDisabled)
                .frame(maxWidth: .infinity)
                .frame(height: Metrics.monthHeight)
                .background(isSelected ? Color.ecoPrimary : Color.ecoDivider, in: RoundedRectangle(cornerRadius: Radius.button))
                .contentShape(RoundedRectangle(cornerRadius: Radius.button))
        }
        .buttonStyle(PassthroughButtonStyle())
        .disabled(!isEnabled)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func actionButton(_ title: LocalizedStringKey, background: Color, foreground: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .ecoFont(.title5)
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity)
                .frame(height: Metrics.actionHeight)
                .background(background, in: RoundedRectangle(cornerRadius: Radius.button))
                .contentShape(RoundedRectangle(cornerRadius: Radius.button))
        }
        .buttonStyle(PassthroughButtonStyle())
    }
}

extension View {
    /// 화면 전체(탭 바 포함)를 딤으로 덮고 가운데에 월 선택 카드를 띄운다. 딤을 누르면 취소한다.
    func ecoMonthPicker(
        isPresented: Binding<Bool>,
        selection: YearMonth,
        range: ClosedRange<YearMonth>,
        yearTitle: @escaping (Int) -> String,
        monthTitle: @escaping (YearMonth) -> String,
        onApply: @escaping (YearMonth) -> Void
    ) -> some View {
        modifier(EcoMonthPickerModifier(
            isPresented: isPresented,
            selection: selection,
            range: range,
            yearTitle: yearTitle,
            monthTitle: monthTitle,
            onApply: onApply
        ))
    }
}

private struct EcoMonthPickerModifier: ViewModifier {
    @Binding var isPresented: Bool
    let selection: YearMonth
    let range: ClosedRange<YearMonth>
    let yearTitle: (Int) -> String
    let monthTitle: (YearMonth) -> String
    let onApply: (YearMonth) -> Void

    func body(content: Content) -> some View {
        content
            // fullScreenCover의 아래에서 올라오는 전환 대신 딤·카드가 스스로 서서히 나타나게 한다.
            .transaction(value: isPresented) { $0.disablesAnimations = true }
            .fullScreenCover(isPresented: $isPresented) {
                DimmedDialog(onDismiss: { isPresented = false }) {
                    EcoMonthPickerDialog(
                        selection: selection,
                        range: range,
                        yearTitle: yearTitle,
                        monthTitle: monthTitle,
                        onApply: { month in
                            isPresented = false
                            onApply(month)
                        },
                        onCancel: { isPresented = false }
                    )
                }
                .presentationBackground(.clear)
            }
    }
}

/// Figma `배경 딤` (504:172) 위 가운데 카드.
private struct DimmedDialog<Content: View>: View {
    let onDismiss: () -> Void
    @ViewBuilder let content: Content

    @State private var isVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.ecoDim
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)
                .accessibilityHidden(true)
            content
                .padding(.horizontal, Spacing.screenHorizontal)
                .accessibilityAddTraits(.isModal)
                .accessibilityAction(.escape, onDismiss)
        }
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(reduceMotion ? nil : .easeOut(duration: Metrics.fadeDuration)) { isVisible = true }
        }
    }
}

/// `.plain`은 비활성일 때 한 번 더 흐리게 그려 지정한 비활성 색과 달라진다.
private struct PassthroughButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}

private enum Metrics {
    static let width: CGFloat = 342
    static let columns = 3
    static let yearButtonSize: CGFloat = 44
    static let monthHeight: CGFloat = 48
    static let actionHeight: CGFloat = 52
    static let fadeDuration: Double = 0.2
}

#Preview {
    ZStack {
        Color.ecoDim.ignoresSafeArea()
        EcoMonthPickerDialog(
            selection: YearMonth(year: 2026, month: 9),
            range: YearMonth(year: 2026, month: 3)...YearMonth(year: 2026, month: 10),
            yearTitle: { ActivityRecordsFormatter.year($0) },
            monthTitle: { ActivityRecordsFormatter.monthOnly($0) },
            onApply: { _ in },
            onCancel: {}
        )
        .padding(.horizontal, Spacing.screenHorizontal)
    }
}
