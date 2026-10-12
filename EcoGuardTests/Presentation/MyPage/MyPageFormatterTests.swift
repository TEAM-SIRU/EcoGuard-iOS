import Testing
@testable import EcoGuard

@MainActor
struct MyPageFormatterTests {
    @Test func affiliationAddsGuardianRole() {
        #expect(MyPageFormatter.affiliation(of: UserProfile(name: "최민준", grade: 2, classNumber: 3, isGuardian: true)) == "2학년 3반 · 환경지킴이")
        #expect(MyPageFormatter.affiliation(of: UserProfile(name: "최민준", grade: 2, classNumber: 3, isGuardian: false)) == "2학년 3반")
    }

    /// 서버에 내 정보 API가 없어 학반을 모를 때.
    @Test func affiliationWithoutClass() {
        #expect(MyPageFormatter.affiliation(of: UserProfile(name: "최민준", grade: nil, classNumber: nil, isGuardian: true)) == "환경지킴이")
        #expect(MyPageFormatter.affiliation(of: UserProfile(name: "최민준", grade: nil, classNumber: nil, isGuardian: false)).isEmpty)
    }

    @Test func statsKeepFigmaUnits() {
        #expect(MyPageFormatter.count(7) == "7회")
        #expect(MyPageFormatter.minutes(70) == "70분")
    }
}
