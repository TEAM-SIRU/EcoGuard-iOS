nonisolated struct LoginRequestDTO: Encodable, Sendable {
    let authCode: String
}

nonisolated struct RefreshRequestDTO: Encodable, Sendable {
    let refreshToken: String
}

nonisolated struct TokenResponseDTO: Decodable, Sendable {
    let accessToken: String
    let refreshToken: String
}

nonisolated struct LoginResponseDTO: Decodable, Sendable {
    struct User: Decodable, Sendable {
        enum Role: Decodable, Sendable {
            case student
            case teacher
            case unknown

            init(from decoder: Decoder) throws {
                switch try decoder.singleValueContainer().decode(String.self) {
                case "STUDENT": self = .student
                case "TEACHER": self = .teacher
                default: self = .unknown
                }
            }
        }

        let userId: Int64
        let name: String
        let role: Role
    }

    let accessToken: String
    let refreshToken: String
    let user: User
}

/// 401(UNAUTHORIZED)을 뺀 에러 응답 바디.
nonisolated struct ErrorResponseDTO: Decodable, Sendable {
    let code: String
    let message: String
}
