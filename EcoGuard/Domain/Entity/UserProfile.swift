/// 로그인한 학생의 dataGSM 계정 정보. 앱에서 고칠 수 없다.
struct UserProfile: Hashable {
    let name: String
    /// 서버에 내 정보 API가 없어 실제 저장소에서는 학년·반이 nil이다(서버 요청 목록).
    let grade: Int?
    let classNumber: Int?
    /// 환경지킴이로 선발돼 활동 중인지.
    let isGuardian: Bool
}
