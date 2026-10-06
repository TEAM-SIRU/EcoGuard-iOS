nonisolated extension TokenResponseDTO {
    var tokens: AuthTokens {
        AuthTokens(accessToken: accessToken, refreshToken: refreshToken)
    }
}

nonisolated extension LoginResponseDTO {
    var tokens: AuthTokens {
        AuthTokens(accessToken: accessToken, refreshToken: refreshToken)
    }

    var sessionUser: SessionUser {
        SessionUser(userId: user.userId, name: user.name)
    }

    /// 알 수 없는 역할이면 nil. 로그인 실패로 처리한다.
    var userRole: UserRole? {
        switch user.role {
        case .student: .student
        case .teacher: .teacher
        case .unknown: nil
        }
    }
}
