import Foundation

/// 모집 공고. 신청 기간인지는 기기 시간이 아니라 서버가 내려준 `phase`로 판단한다.
struct RecruitmentDetail: Equatable {
    enum Phase: Equatable {
        case upcoming
        case open
        case ended
    }

    /// 학기 · 반별 정원 · 내 반 · 현재 신청 인원.
    let recruitment: Recruitment
    let startDate: Date
    let endDate: Date
    let activityWindow: CleaningWindow
    let phase: Phase
    /// 이미 신청했으면 내 신청.
    let myApplication: RecruitmentApplication?

    var remainingSeats: Int {
        max(recruitment.capacityPerClass - recruitment.appliedCount, 0)
    }

    /// 화면에 보여 줄 상태. 이미 신청 > 기간 아님 > 정원 마감 > 신청 가능 순으로 정한다.
    var status: RecruitmentStatus {
        if let myApplication {
            return .applied(myApplication)
        }
        switch phase {
        case .upcoming:
            return .upcoming
        case .ended:
            return .ended
        case .open:
            return remainingSeats == 0 ? .full : .open
        }
    }
}

enum RecruitmentStatus: Equatable {
    case open
    /// 내 반 정원이 찼다.
    case full
    case applied(RecruitmentApplication)
    /// 신청 기간 전.
    case upcoming
    /// 신청 기간이 지났다.
    case ended
}
