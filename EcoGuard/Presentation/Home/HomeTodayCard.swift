import SwiftUI

/// Figma `Today card` (238:201). 오늘 인증 상태마다 제목·정보·버튼이 바뀐다.
struct HomeTodayCard: View {
    let today: TodayCleaning
    let actions: HomeView.Actions

    var body: some View {
        EcoCard(.content) {
            VStack(alignment: .leading, spacing: 0) {
                Text("오늘의 청소")
                    .ecoFont(.body2Medium)
                    .foregroundStyle(Color.ecoTextSub)
                Text(title)
                    .ecoFont(.title2)
                    .foregroundStyle(Color.ecoTextPrimary)
                    .padding(.top, Spacing.md)
                    .padding(.bottom, Spacing.xl)
                    .accessibilityAddTraits(.isHeader)
                infoTable
                detail
                button
                    .padding(.top, Spacing.xl)
            }
        }
    }

    private var title: LocalizedStringKey {
        switch today.verification {
        case .notOpenYet: "\(HomeFormatter.time(minuteOfDay: today.window.startMinute))부터 인증할 수 있어요"
        case .open: "아직 인증하지 않았어요"
        case .aiReviewing: "AI가 사진을 확인하고 있어요"
        case .teacherReviewing: "선생님이 사진을 확인하고 있어요"
        case .approved: "오늘 청소를 마쳤어요"
        case .rejected: "인증이 반려됐어요"
        }
    }

    private var infoTable: some View {
        VStack(spacing: Spacing.md) {
            HomeInfoRow(label: "청소 시간", value: HomeFormatter.window(today.window))
            HomeInfoRow(label: "담당 구역", value: today.area)
            switch today.verification {
            case .aiReviewing(let submittedAt), .teacherReviewing(let submittedAt):
                HomeInfoRow(label: "제출", value: String(localized: "오늘 \(HomeFormatter.clockTime(submittedAt))"))
            case .approved(let earnedMinutes):
                HomeInfoRow(label: "적립", value: String(localized: "+\(earnedMinutes)분"), isHighlighted: true)
            case .notOpenYet, .open, .rejected:
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch today.verification {
        case .open(let deadline):
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text("인증 마감까지 \(HomeFormatter.countdown(deadline.timeIntervalSince(context.date)))")
                    .ecoFont(.body2)
                    .foregroundStyle(Color.ecoPrimaryText)
                    .monospacedDigit()
            }
        case .rejected(let reason):
            EcoInfoBox(style: .warning(title: "반려 사유"), message: reason)
                .padding(.top, Spacing.md)
        case .teacherReviewing:
            EcoInfoBox(style: .note, message: String(localized: "AI가 판단하기 어려운 사진이라 선생님께 넘겼어요"))
                .padding(.top, Spacing.md)
        case .notOpenYet, .aiReviewing, .approved:
            EmptyView()
        }
    }

    @ViewBuilder
    private var button: some View {
        switch today.verification {
        case .notOpenYet:
            EcoButton("지금은 인증 시간이 아니에요", leadingIcon: .iconClockLarge) {}
                .disabled(true)
        case .open:
            EcoButton("청소 인증하기", leadingIcon: .iconCam, action: actions.verify)
        case .aiReviewing, .teacherReviewing:
            EcoButton("제출한 사진 보기", style: .secondary, action: actions.openSubmittedPhoto)
        case .approved:
            EcoButton("기록 보기", style: .secondary, action: actions.openRecords)
        case .rejected:
            EcoButton("이의신청하기", action: actions.appeal)
        }
    }
}

/// 카드 안 `라벨 ··· 값` 한 줄. Figma `Info table` (238:210).
private struct HomeInfoRow: View {
    let label: LocalizedStringKey
    let value: String
    var isHighlighted = false

    var body: some View {
        HStack {
            Text(label)
                .ecoFont(.body2)
                .foregroundStyle(Color.ecoTextCaption)
            Spacer()
            Text(value)
                .ecoFont(.body2Medium)
                .foregroundStyle(isHighlighted ? Color.ecoPrimaryText : Color.ecoTextPrimary)
        }
        .accessibilityElement(children: .combine)
    }
}
