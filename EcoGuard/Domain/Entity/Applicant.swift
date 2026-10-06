/// dataGSM 계정 정보로 채우는 신청자. 앱에서 고칠 수 없다.
/// 서버가 모르는 값(dataGSM에 학번이 없음 등)은 nil이고 화면에서 그 줄을 숨긴다.
struct Applicant: Hashable {
    let studentNumber: String?
    let name: String?
}
