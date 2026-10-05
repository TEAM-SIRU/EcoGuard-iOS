import SwiftUI

/// Figma `Recruit card` (255:583 모집 기간 · 313:262 구역 배정 대기).
/// 확정 대기·미선발·모집 없음은 Figma에 없어 같은 카드에 버튼 없이 사실만 보여 준다(`HomeStatusCopy`).
struct HomeRecruitCard: View {
    enum Content {
        case recruiting(Recruitment)
        case awaitingAssignment
        case applicationPending
        case notSelected
        case notRecruiting
    }

    let content: Content
    /// 버튼이 있는 상태(모집·배정 대기)에서만 쓴다.
    var action: () -> Void = {}

    var body: some View {
        EcoCard(.content) {
            VStack(alignment: .leading, spacing: 0) {
                EcoTag(title: tagTitle, style: .tint)
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text(title)
                        .ecoFont(.title2)
                        .foregroundStyle(Color.ecoTextPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Text(message)
                        .ecoFont(.body2)
                        .foregroundStyle(Color.ecoTextSub)
                }
                .padding(.top, Spacing.md)
                .padding(.bottom, Spacing.lg)
                if case .recruiting(let recruitment) = content {
                    progress(recruitment)
                }
                if let button {
                    button
                        .padding(.top, Spacing.xl)
                }
            }
        }
    }

    private var tagTitle: LocalizedStringKey {
        switch content {
        case .recruiting: "모집 중"
        case .awaitingAssignment: "신청 완료"
        case .applicationPending: HomeStatusCopy.ApplicationPending.tag
        case .notSelected: HomeStatusCopy.NotSelected.tag
        case .notRecruiting: HomeStatusCopy.NotRecruiting.tag
        }
    }

    private var title: LocalizedStringKey {
        switch content {
        case .recruiting(let recruitment): "\(recruitment.semester)학기 환경지킴이를\n모집하고 있어요"
        case .awaitingAssignment: "환경지킴이가 됐어요"
        case .applicationPending: HomeStatusCopy.ApplicationPending.title
        case .notSelected: HomeStatusCopy.NotSelected.title
        case .notRecruiting: HomeStatusCopy.NotRecruiting.title
        }
    }

    private var message: LocalizedStringKey {
        switch content {
        case .recruiting(let recruitment): "반마다 \(recruitment.capacityPerClass)명, 먼저 신청한 순서대로 확정돼요"
        case .awaitingAssignment: "선생님이 청소 구역을 배정하면 여기서 바로 알려드려요"
        case .applicationPending: HomeStatusCopy.ApplicationPending.message
        case .notSelected: HomeStatusCopy.NotSelected.message
        case .notRecruiting: HomeStatusCopy.NotRecruiting.message
        }
    }

    private func progress(_ recruitment: Recruitment) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(recruitment.className)
                    .ecoFont(.body2Medium)
                    .foregroundStyle(Color.ecoTextSub)
                Spacer()
                Text("\(recruitment.appliedCount)/\(recruitment.capacityPerClass)명")
                    .ecoFont(.body2Bold)
                    .foregroundStyle(Color.ecoPrimaryText)
                    .accessibilityLabel(Text("\(recruitment.capacityPerClass)명 중 \(recruitment.appliedCount)명 신청"))
            }
            .accessibilityElement(children: .combine)
            EcoProgressBar(progress: Double(recruitment.appliedCount) / Double(max(recruitment.capacityPerClass, 1)))
        }
    }

    private var button: EcoButton? {
        switch content {
        case .recruiting:
            EcoButton("모집 공고 보기", action: action)
        case .awaitingAssignment:
            EcoButton("신청 결과 보기", style: .secondary, action: action)
        case .applicationPending, .notSelected, .notRecruiting:
            nil
        }
    }
}
