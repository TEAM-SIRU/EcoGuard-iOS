enum AuthError: Error, Equatable {
    /// 사용자가 dataGSM OAuth 창을 닫아 로그인을 취소했다. 오류로 안내하지 않는다.
    case cancelled
}
