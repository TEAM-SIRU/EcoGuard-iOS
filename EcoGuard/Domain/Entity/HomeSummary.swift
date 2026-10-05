/// 홈 화면 한 번 조회 결과. 상태 판단은 서버 값을 그대로 쓴다.
struct HomeSummary: Equatable {
    let status: HomeStatus
    /// 메인에 크게 띄울 새 공지. 닫았거나 없으면 nil.
    let notice: Notice?

    func removingNotice() -> HomeSummary {
        HomeSummary(status: status, notice: nil)
    }
}

/// 가입·배정 상태에 따라 홈 본문이 달라진다.
enum HomeStatus: Equatable {
    /// 모집 기간이고 아직 신청하지 않았다.
    case recruiting(Recruitment)
    /// 선발됐고 선생님이 구역을 배정하기 전이다.
    case awaitingAssignment
    /// 이번 모집에 신청했고 선생님 확정을 기다린다.
    case applicationPending
    /// 이번 모집에서 선발되지 않았다.
    case notSelected
    /// 모집 기간이 아니고 이번 모집에 신청하지도 않았다.
    case notRecruiting
    /// 담당 선생님이 활동에서 제외했다.
    case excluded(reason: String)
    /// 구역을 배정받아 활동 중이다.
    case active(ActiveCleaning)
}

struct ActiveCleaning: Equatable {
    let today: TodayCleaning
    let week: WeeklyCleaning
    let recentRecords: [CleaningRecord]
}
