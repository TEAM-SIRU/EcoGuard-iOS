import Foundation

/// 최근 청소 기록 한 건.
struct CleaningRecord: Equatable, Identifiable {
    enum Result: Equatable {
        case approved(earnedMinutes: Int)
        case rejected
        case processing
    }

    let id: String
    let cleanedAt: Date
    let area: String
    let result: Result
}
