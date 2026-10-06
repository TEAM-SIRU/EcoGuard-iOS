/// 로그인한 사용자 요약(로그인 응답 기준). 학년·반은 서버가 주지 않는다.
struct CurrentUser: Hashable {
    let id: String
    let name: String
}
