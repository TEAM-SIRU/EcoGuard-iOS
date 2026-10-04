import Testing
@testable import EcoGuard

@MainActor
struct MyPageFormatterTests {
    @Test func initialsUseLastTwoCharactersOfLongNames() {
        #expect(MyPageFormatter.initials(of: "최민준") == "민준")
        #expect(MyPageFormatter.initials(of: "남궁민수") == "민수")
        #expect(MyPageFormatter.initials(of: "민준") == "민준")
        #expect(MyPageFormatter.initials(of: " 최민준 ") == "민준")
    }

    @Test func affiliationAddsGuardianRole() {
        #expect(MyPageFormatter.affiliation(of: UserProfile(name: "최민준", grade: 2, classNumber: 3, isGuardian: true)) == "2학년 3반 · 환경지킴이")
        #expect(MyPageFormatter.affiliation(of: UserProfile(name: "최민준", grade: 2, classNumber: 3, isGuardian: false)) == "2학년 3반")
    }

    @Test func statsKeepFigmaUnits() {
        #expect(MyPageFormatter.count(7) == "7회")
        #expect(MyPageFormatter.minutes(70) == "70분")
    }
}
