/// `GET /users/me`. 서버 계약: EcoGuard-Server `user/dto/UserDtos.kt`.
nonisolated struct MyProfileResponseDTO: Decodable, Sendable {
    let userId: Int64
    let name: String
    /// 학생 계정에만 있다. dataGSM에 없으면 학생도 nil일 수 있다.
    let studentNumber: String?
    let grade: Int?
    let classNo: Int?
}
