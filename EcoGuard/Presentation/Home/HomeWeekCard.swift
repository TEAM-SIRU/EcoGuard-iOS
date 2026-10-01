import SwiftUI

/// Figma `Week card` (306:2). 이번 주 청소 현황 N/5일.
struct HomeWeekCard: View {
    let week: WeeklyCleaning

    var body: some View {
        EcoCard(.plain) {
            VStack(spacing: Spacing.lg) {
                HStack {
                    Text("이번 주 청소")
                        .ecoFont(.body1Bold)
                        .foregroundStyle(Color.ecoTextPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    Text("\(week.completedCount)/\(week.days.count)일")
                        .ecoFont(.body2Medium)
                        .foregroundStyle(Color.ecoPrimaryText)
                }
                HStack(alignment: .top, spacing: 0) {
                    ForEach(Array(week.days.enumerated()), id: \.offset) { index, day in
                        if index > 0 {
                            Spacer(minLength: 0)
                        }
                        WeekDayIndicator(
                            label: day.isToday ? String(localized: "오늘") : HomeFormatter.weekdaySymbol(day.weekday),
                            isToday: day.isToday,
                            isCompleted: day.isCompleted
                        )
                    }
                }
            }
        }
    }
}
