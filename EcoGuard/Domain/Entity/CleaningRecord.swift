import Foundation

/// 최근 청소 기록 한 건.
struct CleaningRecord: Equatable, Identifiable {
    enum Result: Equatable {
        case approved(earnedMinutes: Int)
        case rejected
        case processing
    }

    let id: String
    /// 청소한 날. 학교 시간대(KST) 기준 그날 0시.
    let date: Date
    /// 사진을 낸 시각. 서버가 시각을 주지 않으면(현재 서버) nil.
    let cleanedAt: Date?
    let area: String
    let result: Result
}
