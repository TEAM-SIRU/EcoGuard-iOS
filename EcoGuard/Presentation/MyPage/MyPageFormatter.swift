import Foundation

/// 마이페이지 표시 문자열.
enum MyPageFormatter {
    /// "2학년 3반 · 환경지킴이". 환경지킴이가 아니면 학반만, 학반을 모르면 "환경지킴이"만.
    static func affiliation(of profile: UserProfile) -> String {
        let classText = profile.grade.flatMap { grade in profile.classNumber.map { "\(grade)학년 \($0)반" } }
        let parts = [classText, profile.isGuardian ? "환경지킴이" : nil]
        return parts.compactMap(\.self).joined(separator: " · ")
    }

    /// "7회"
    static func count(_ value: Int) -> String {
        "\(value)회"
    }

    /// "70분". Figma가 60분이 넘어도 분으로만 쓴다.
    static func minutes(_ value: Int) -> String {
        "\(value)분"
    }
}
