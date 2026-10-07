import Foundation

/// 반려된 청소 인증에 보낸 이의신청 한 건. 같은 인증에 횟수 제한 없이 다시 보낼 수 있고 `round`가 N차다.
struct Appeal: Equatable, Hashable, Identifiable {
    /// 선생님 검토 상태. 서버 값(`REVIEWING` 등)을 rawValue로 둔다.
    enum Status: String, Equatable, Hashable {
        case reviewing = "REVIEWING"
        case approved = "APPROVED"
        case rejected = "REJECTED"
    }

    /// 반려할 때 선생님이 남긴 답변. `message`는 다시 보낼 때 참고할 안내다.
    struct TeacherReply: Equatable, Hashable {
        let title: String
        let message: String?
    }

    let id: String
    /// 대상 인증.
    let verificationID: String
    /// 대상 인증을 제출한 시각.
    let verifiedAt: Date
    /// 같은 인증에 보낸 몇 번째 이의신청인지(1부터).
    let round: Int
    let submittedAt: Date
    let status: Status
    /// 승인되어 활동 시간에 더한 분. 승인 전이거나, 승인됐어도 대상 인증이 이미 승인돼 있어 더하지 않았으면 nil이다.
    let earnedMinutes: Int?
    /// 반려일 때만 있다.
    let teacherReply: TeacherReply?
    /// 이의신청에 첨부한 사진 주소. 사진은 선택이라 비어 있을 수 있다.
    let photoURLs: [URL]
    /// 서버가 대상 인증의 날짜만 주면 false이고 `verifiedAt`은 그날 00:00이다. 화면은 날짜만 보여 준다.
    var isVerifiedTimeKnown = true

    /// 반려된 이의신청에서 `다시 이의신청하기`로 쓸 대상. 반려 사유는 가장 최근 판단인 선생님 답변이다.
    var retryTarget: AppealTarget {
        AppealTarget(verificationID: verificationID, verifiedAt: verifiedAt, rejectionReason: teacherReply?.title)
    }
}

/// 이의신청할 반려된 인증.
struct AppealTarget: Equatable, Hashable {
    let verificationID: String
    let verifiedAt: Date
    /// 작성 화면 `반려 사유`. 사유 없이 반려됐으면 nil.
    let rejectionReason: String?
}

extension AppealTarget {
    init(result: VerificationResult) {
        self.init(verificationID: result.id, verifiedAt: result.submittedAt, rejectionReason: result.rejectionReason?.title)
    }
}

/// 이의신청에 첨부할 사진. 카메라로 찍은 사진만 받는다(앨범 사진 금지).
struct AppealPhoto: Equatable, Identifiable {
    let id: UUID
    let jpegData: Data
}

/// 보낼 이의신청. `requestID`는 작성 화면마다 하나라, 실패한 제출이 서버에 닿았는지 같은 값으로 확인한다.
struct AppealDraft: Equatable {
    let requestID: String
    let verificationID: String
    let message: String
    let photos: [AppealPhoto]
}

enum AppealError: Error, Equatable {
    /// 같은 인증에 검토 중인 이의신청이 이미 있다. 그 이의신청을 들고 있다.
    case alreadyPending(Appeal)
}

/// 이의신청 제출 결과.
enum AppealSubmissionResult: Equatable {
    case submitted(Appeal)
    /// 앞서 응답을 받지 못한 제출이 이미 접수돼 있었고, 그 뒤 고친 지금 내용과 다르다.
    /// 같은 `requestID`라 지금 내용은 보내지 않는다(중복 접수 방지). 처음 접수된 내용으로 완료된 것을 알려야 한다.
    case alreadyReceived(Appeal)
}

/// 이의신청 내용 입력 규칙.
enum AppealMessage {
    static let maxLength = 300
    static let maxPhotoCount = 3

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
    static func length(of text: String) -> Int {
        trimmed(text).count
    }

    static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
