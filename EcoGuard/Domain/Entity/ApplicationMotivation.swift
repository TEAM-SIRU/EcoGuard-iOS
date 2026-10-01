import Foundation

/// 신청 동기 입력 규칙.
enum ApplicationMotivation {
    static let maxLength = 200

    enum Validation: Equatable {
        /// 비어 있거나 공백뿐이다.
        case empty
        case tooLong
        case valid
    }

    /// 공백뿐이면 빈 값이다. 길이는 화면 글자 수 표시와 같게 입력한 그대로(사용자가 보는 글자 단위) 센다.
    static func validate(_ text: String) -> Validation {
        if trimmed(text).isEmpty {
            return .empty
        }
        return text.count > maxLength ? .tooLong : .valid
    }

    static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
