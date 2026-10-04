import Foundation

/// 마이페이지 표시 문자열.
enum MyPageFormatter {
    /// 아바타 글자. 세 글자 이상이면 끝 두 글자("최민준" → "민준", "남궁민수" → "민수"), 두 글자 이하면 그대로 쓴다.
    static func initials(of name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 3 else { return trimmed }
        return String(trimmed.suffix(2))
    }

    /// "2학년 3반 · 환경지킴이". 환경지킴이가 아니면 학반만.
    static func affiliation(of profile: UserProfile) -> String {
        let classText = "\(profile.grade)학년 \(profile.classNumber)반"
        return profile.isGuardian ? "\(classText) · 환경지킴이" : classText
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
