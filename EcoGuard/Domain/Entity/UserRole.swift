/// 로그인한 계정의 역할. 앱은 학생만 이용하고 교사는 웹으로 안내한다.
enum UserRole: Equatable {
    case student
    case teacher
}
