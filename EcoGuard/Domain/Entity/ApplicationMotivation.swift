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

    /// 빈 값·길이 모두 앞뒤 공백을 뺀 값(서버로 보내는 값)으로 판단한다.
    static func validate(_ text: String) -> Validation {
        let length = length(of: text)
        if length == 0 {
            return .empty
        }
        return length > maxLength ? .tooLong : .valid
    }

    /// 화면 글자 수와 검증에 같이 쓰는 길이. 앞뒤 공백을 빼고 사용자가 보는 글자 단위로 센다.
    /// 서버가 UTF-16 단위로 세면 이모지 등에서 달라질 수 있어 연동 때 맞춰야 한다.
    static func length(of text: String) -> Int {
        trimmed(text).count
    }

    static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
