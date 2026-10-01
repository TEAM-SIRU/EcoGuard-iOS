import SwiftUI

/// Figma `Week card` 요일 하나 (306:7). 40 원 + 요일 글자.
/// 완료한 날은 초록 원에 체크, 오늘은 초록 테두리, 나머지는 회색 테두리.
struct WeekDayIndicator: View {
    let label: String
    let isToday: Bool
    let isCompleted: Bool

    var body: some View {
        VStack(spacing: Metrics.spacing) {
            circle
            Text(label)
                .ecoFont(isToday ? .caption : .captionRegular)
                .foregroundStyle(isToday ? Color.ecoPrimaryText : Color.ecoTextCaption)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label))
        .accessibilityValue(isCompleted ? Text("완료") : Text("미완료"))
    }

    @ViewBuilder
    private var circle: some View {
        if isCompleted {
            Image(.iconCheckLarge)
                .foregroundStyle(Color.ecoOnPrimary)
                .frame(width: Metrics.size, height: Metrics.size)
                .background(Color.ecoPrimary, in: Circle())
        } else {
            Circle()
                .fill(Color.ecoCard)
                .overlay {
                    Circle()
                        .strokeBorder(
                            isToday ? Color.ecoPrimary : Color.ecoBorder,
                            lineWidth: isToday ? Metrics.todayBorder : Metrics.border
                        )
                }
                .frame(width: Metrics.size, height: Metrics.size)
        }
    }
}

private enum Metrics {
    static let size: CGFloat = 40
    static let spacing: CGFloat = 6
    static let border: CGFloat = 1
    static let todayBorder: CGFloat = 2
}

#Preview {
    HStack {
        WeekDayIndicator(label: "월", isToday: false, isCompleted: true)
        WeekDayIndicator(label: "오늘", isToday: true, isCompleted: false)
        WeekDayIndicator(label: "오늘", isToday: true, isCompleted: true)
        WeekDayIndicator(label: "수", isToday: false, isCompleted: false)
    }
}
