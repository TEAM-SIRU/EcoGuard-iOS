enum RecruitmentError: Error {
    /// 신청하는 사이 반 정원이 찼다.
    case full
    /// 신청하는 사이 신청 기간이 끝났다.
    case notInPeriod
    /// 이미 신청했다. 서버가 기존 신청을 함께 내려준다.
    case alreadyApplied(RecruitmentApplication)
}
