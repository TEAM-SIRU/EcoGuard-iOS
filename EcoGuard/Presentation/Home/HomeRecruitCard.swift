import SwiftUI

/// Figma `Recruit card` (255:583 모집 기간 · 313:262 구역 배정 대기).
struct HomeRecruitCard: View {
    enum Content {
        case recruiting(Recruitment)
        case awaitingAssignment
    }

    let content: Content
    let action: () -> Void

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
                button
                    .padding(.top, Spacing.xl)
            }
        }
    }

    private var tagTitle: LocalizedStringKey {
        switch content {
        case .recruiting: "모집 중"
        case .awaitingAssignment: "신청 완료"
        }
    }

    private var title: LocalizedStringKey {
        switch content {
        case .recruiting(let recruitment): "\(recruitment.semester)학기 환경지킴이를\n모집하고 있어요"
        case .awaitingAssignment: "환경지킴이가 됐어요"
        }
    }

    private var message: LocalizedStringKey {
        switch content {
        case .recruiting(let recruitment): "반마다 \(recruitment.capacityPerClass)명, 먼저 신청한 순서대로 확정돼요"
        case .awaitingAssignment: "선생님이 청소 구역을 배정하면 여기서 바로 알려드려요"
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
            }
            .accessibilityElement(children: .combine)
            EcoProgressBar(progress: Double(recruitment.appliedCount) / Double(max(recruitment.capacityPerClass, 1)))
        }
    }

    @ViewBuilder
    private var button: some View {
        switch content {
        case .recruiting:
            EcoButton("모집 공고 보기", action: action)
        case .awaitingAssignment:
            EcoButton("신청 결과 보기", style: .secondary, action: action)
        }
    }
}
