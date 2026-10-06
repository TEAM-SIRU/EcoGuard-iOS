import SwiftUI

/// 모집·신청 화면 문구. 바꿀 때는 이 파일만 고친다.
/// `Figma`는 프레임에 적힌 그대로이고, `새 문구`는 Figma에 프레임이 없어 새로 썼다(디자이너 확인 필요).
enum RecruitmentCopy {
    enum Common {
        /// Figma 514:136 · 246:112
        static let home: LocalizedStringKey = "홈으로"
        /// Figma 514:136
        static let retry: LocalizedStringKey = "다시 시도"
        /// 새 문구. 불러오는 중 VoiceOver 안내.
        static let loading: LocalizedStringKey = "불러오는 중이에요"
    }

    enum Notice {
        // Figma 246:3 · 313:2 · 313:53
        /// 학기를 모르면 학기 없이(새 문구).
        static func title(semester: Int?) -> LocalizedStringKey {
            semester.map { "\($0)학기 환경지킴이를 모집해요" } ?? "환경지킴이를 모집해요"
        }
        static func subtitle(capacity: Int) -> LocalizedStringKey { "반마다 최대 \(capacity)명, 먼저 신청한 순서대로 확정돼요" }
        static let periodLabel: LocalizedStringKey = "모집 기간"
        static let capacityLabel: LocalizedStringKey = "모집 인원"
        static func capacityValue(_ capacity: Int) -> String { "반별 최대 \(capacity)명" }
        static let activityLabel: LocalizedStringKey = "활동 시간"
        static func progressTitle(className: String) -> String { "\(className) 신청 현황" }
        static func progressValue(applied: Int, capacity: Int) -> String { "\(applied)/\(capacity)명" }
        /// 새 문구. VoiceOver가 "4/6명" 대신 읽는다.
        static func progressAccessibility(applied: Int, capacity: Int) -> String { "\(capacity)명 중 \(applied)명 신청" }
        static func openCaption(remainingSeats: Int) -> String { "\(remainingSeats)자리 남았어요. 자리가 차면 바로 마감돼요" }
        static func fullCaption(className: String) -> String { "\(className)은 자리가 모두 찼어요. 다음 모집을 기다려 주세요" }
        static func appliedCaption(appliedAt: String, order: Int) -> String { "\(appliedAt)에 \(order)번째로 신청했어요" }
        static let benefitTitle = "인증 1번에 봉사시간 10분"
        static let benefitSubtitle = "인증이 승인되면 활동 기록에 쌓여요"
        static let howTitle = "사진 1장으로 간단하게 인증"
        static let howSubtitle = "청소를 마치고 카메라로 찍어 보내요"
        static let apply: LocalizedStringKey = "신청하기"
        static let closed: LocalizedStringKey = "모집이 마감됐어요"

        // 새 문구: 신청 기간 전·후
        static func upcomingCaption(startDay: String) -> String { "\(startDay)부터 신청할 수 있어요" }
        static let endedCaption = "신청 기간이 끝났어요. 다음 모집을 기다려 주세요"
        static let notInPeriod: LocalizedStringKey = "신청 기간이 아니에요"

        // 새 문구: 공고 없음
        static let emptyTitle: LocalizedStringKey = "지금은 모집 공고가 없어요"
        static let emptyMessage: LocalizedStringKey = "모집이 시작되면 홈에서 알려드려요."

        // Figma 514:136
        static let failedTitle: LocalizedStringKey = "모집 공고를 불러오지 못했어요"
        static let failedMessage: LocalizedStringKey = "모집 상태를 확인하지 못했어요.\n다시 불러온 뒤 신청 가능 여부를 확인해 주세요."
    }

    enum Apply {
        // Figma 309:169
        static let title: LocalizedStringKey = "환경지킴이 신청"
        /// 신청하면 바로 확정된다(선착순, 2026-10-03 결정).
        static func subtitle(capacity: Int) -> LocalizedStringKey { "신청하면 바로 확정돼요.\n반마다 \(capacity)명이 차면 마감돼요." }
        static let submit: LocalizedStringKey = "신청하기"

        // 새 문구: 신청자 정보·신청 동기 입력
        static let studentNumberLabel: LocalizedStringKey = "학번"
        static let nameLabel: LocalizedStringKey = "이름"
        static let motivationTitle: LocalizedStringKey = "신청 동기"
        static let motivationPrompt: LocalizedStringKey = "환경지킴이로 활동하고 싶은 이유를 적어 주세요"
        static func motivationTooLong(maxLength: Int) -> LocalizedStringResource { "\(maxLength)자까지 쓸 수 있어요" }
        static let motivationRequired: LocalizedStringKey = "신청 동기를 입력하면 신청할 수 있어요"
        static let failed: LocalizedStringResource = "신청하지 못했어요. 다시 시도해 주세요"
    }

    enum Result {
        // Figma 246:112
        static let approvedTitle = "환경지킴이가 됐어요"
        static func appliedLine(order: Int, appliedAt: String) -> String { "\(order)번째로 신청했어요 · \(appliedAt)" }
        static let awaitingAssignment = "청소 구역이 배정되면 알려드려요."

        // Figma 246:128
        static let closedTitle = "신청하지 못했어요"
        static let closedMessage = "신청하는 사이 모집 인원이 모두 찼어요.\n다음 모집 때 다시 신청해 주세요."
        /// 새 문구. 신청하는 사이 신청 기간이 끝났다(제목은 246:128과 같다).
        static let periodEndedMessage = "신청하는 사이 신청 기간이 끝났어요.\n다음 모집 때 다시 신청해 주세요."

        // 새 문구: 구역 배정 완료
        static let areaAssigned = "청소 구역이 배정됐어요. 홈에서 확인해 주세요."

        // 새 문구: 결과 화면 단독 조회
        static let notAppliedTitle: LocalizedStringKey = "아직 신청하지 않았어요"
        static let notAppliedMessage: LocalizedStringKey = "모집 공고에서 신청할 수 있어요."
        static let failedTitle: LocalizedStringKey = "신청 결과를 불러오지 못했어요"
        static let failedMessage: LocalizedStringKey = "잠시 후 다시 시도해 주세요."
    }
}
