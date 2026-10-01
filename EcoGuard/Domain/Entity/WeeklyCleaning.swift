/// 이번 주 청소 현황(월~금).
struct WeeklyCleaning: Equatable {
    struct Day: Equatable {
        /// `Calendar` 기준 요일. 월 = 2 … 금 = 6.
        let weekday: Int
        let isToday: Bool
        let isCompleted: Bool
    }

    let days: [Day]

    var completedCount: Int {
        days.filter(\.isCompleted).count
    }
}
