/// dataGSM 계정 정보로 채우는 신청자. 앱에서 고칠 수 없다.
/// 서버가 주지 않는 값은 nil이고 화면에서 그 줄을 숨긴다(학번은 서버 요청 목록).
struct Applicant: Hashable {
    let studentNumber: String?
    let name: String?
}
