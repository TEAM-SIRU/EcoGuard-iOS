/// 로그인한 사용자(`GET /users/me` 기준). 학번·학년·반은 서버가 모르면 nil이다.
struct CurrentUser: Hashable {
    let id: String
    let name: String
    let studentNumber: String?
    let grade: Int?
    let classNumber: Int?
}
