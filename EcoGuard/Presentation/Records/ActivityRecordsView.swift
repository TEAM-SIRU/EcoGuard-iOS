import SwiftUI

/// Figma `07 활동 기록` (240:3) · `빈 상태` (240:104) · `조회 실패` (317:1286) · `로딩` (514:303) · `월 변경 팝업` (504:17).
struct ActivityRecordsView: View {
    struct Actions {
        /// 빈 상태의 "청소 인증하러 가기". nil이면 버튼을 숨긴다(활동 중이 아니라 인증할 수 없을 때).
        var verify: (() -> Void)?
        /// 기록 행. 그날 인증 상세(결과)를 연다.
        var openRecord: (ActivityRecord) -> Void = { _ in }
    }

    let viewModel: ActivityRecordsViewModel
    var actions = Actions()

    @State private var isMonthPickerPresented = false

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.ecoCard)
            // 처음 들어올 때, 달을 바꿨을 때, 불러오던 중 화면을 떠났다 돌아왔을 때 불러온다. 달을 바꾸면 진행 중인 조회는 취소된다.
            .task(id: viewModel.selectedMonth) {
                guard viewModel.state == .loading else { return }
                await viewModel.load()
            }
            .ecoMonthPicker(
                isPresented: $isMonthPickerPresented,
                selection: viewModel.selectedMonth,
                range: viewModel.selectableMonths,
                yearTitle: { ActivityRecordsFormatter.year($0) },
                monthTitle: { ActivityRecordsFormatter.monthOnly($0) },
                onApply: viewModel.selectMonth
            )
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            ActivityRecordsLoadingView()
        case .failed:
            failedView
        case .loaded(let month):
            loadedView(month)
        }
    }

    /// 제목과 월 선택. 기록·빈 상태·조회 실패가 같은 자리에 둔다.
    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            title
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.xl)
            monthButton
        }
    }

    private var title: some View {
        Text("활동 기록")
            .ecoFont(.title1)
            .foregroundStyle(Color.ecoTextPrimary)
            .accessibilityAddTraits(.isHeader)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.screenHorizontal)
    }

    private var monthButton: some View {
        Button {
            isMonthPickerPresented = true
        } label: {
            HStack(spacing: Spacing.xs) {
                Text(ActivityRecordsFormatter.month(viewModel.selectedMonth))
                    .ecoFont(.body1Bold)
                    .foregroundStyle(Color.ecoTextPrimary)
                Image(.iconChevronDown)
                    .foregroundStyle(Color.ecoTextSub)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("조회할 월을 바꿔요"))
        .padding(.horizontal, Spacing.screenHorizontal)
        .padding(.bottom, Spacing.sm)
    }

    /// 빈 달은 안내를 남은 높이 가운데에 둔다. 당겨서 새로고침이 되도록 스크롤 안에 둔다.
    private func loadedView(_ month: ActivityMonth) -> some View {
        GeometryReader { proxy in
            ScrollView {
                loadedContent(month)
                    .frame(minHeight: proxy.size.height, alignment: .top)
            }
            .refreshable { await viewModel.refresh() }
        }
    }

    private func loadedContent(_ month: ActivityMonth) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            EcoStatSummary(
                title: ActivityRecordsFormatter.totalTitle(viewModel.selectedMonth, current: viewModel.currentMonth),
                value: ActivityRecordsFormatter.minutes(month.totalMinutes),
                isHighlighted: month.totalMinutes > 0,
                stats: [
                    .init(title: String(localized: "승인"), value: ActivityRecordsFormatter.count(month.count(of: .approved))),
                    .init(title: String(localized: "반려"), value: ActivityRecordsFormatter.count(month.count(of: .rejected))),
                    .init(title: String(localized: "미제출"), value: ActivityRecordsFormatter.count(month.count(of: .notSubmitted)))
                ]
            )
            Rectangle()
                .fill(Color.ecoDivider)
                .frame(height: Spacing.md)
                .accessibilityHidden(true)
            if month.records.isEmpty {
                EcoEmptyState(
                    icon: .iconListHero,
                    title: "\(ActivityRecordsFormatter.emptyTitle(viewModel.selectedMonth, current: viewModel.currentMonth))",
                    message: "\(ActivityRecordsFormatter.emptyMessage(viewModel.selectedMonth, current: viewModel.currentMonth))",
                    // 지난 달은 지금 인증해도 쌓이지 않아 이번 달에만 인증으로 보낸다.
                    action: viewModel.isCurrentMonthSelected
                        ? actions.verify.map { verify in .init(title: "청소 인증하러 가기", size: .wide, perform: verify) }
                        : nil
                )
            } else {
                ForEach(Array(viewModel.sections.enumerated()), id: \.element.id) { index, section in
                    sectionView(section, isFirst: index == 0)
                }
            }
        }
    }

    private func sectionView(_ section: ActivityWeekSection, isFirst: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(ActivityRecordsFormatter.weekTitle(weeksAgo: section.weeksAgo))
                .ecoFont(.captionMedium)
                .foregroundStyle(Color.ecoTextCaption)
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.top, isFirst ? Spacing.lg : Spacing.xl)
            ForEach(section.items) { item in
                switch item {
                case .record(let record):
                    recordRow(record)
                case .holiday(let holiday):
                    Text(ActivityRecordsFormatter.holiday(holiday))
                        .ecoFont(.captionRegular)
                        .foregroundStyle(Color.ecoTextCaption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Spacing.screenHorizontal)
                        .padding(.vertical, Spacing.md)
                }
            }
        }
    }

    @ViewBuilder
    private func recordRow(_ record: ActivityRecord) -> some View {
        let row = EcoListRow(
            icon: nil,
            title: ActivityRecordsFormatter.recordDate(record.date),
            subtitle: ActivityRecordsFormatter.detail(record),
            horizontalPadding: Spacing.screenHorizontal
        ) {
            HStack(spacing: Spacing.sm) {
                StatusChip(status: record.result.chipStatus)
                if record.result != .notSubmitted {
                    Image(.iconChevronRightLarge)
                        .foregroundStyle(Color.ecoDisabled)
                        .accessibilityHidden(true)
                }
            }
        }
        // 미제출은 볼 인증 사진이 없어 상세로 가지 않는다.
        if record.result == .notSubmitted {
            row
        } else {
            Button { actions.openRecord(record) } label: {
                row.contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    /// 제목·월 선택은 기록 화면과 같은 자리에 두고 안내를 가운데에 놓는다.
    /// 다른 달은 불러올 수 있을 수 있어 실패 화면에서도 달을 바꿀 수 있게 둔다.
    private var failedView: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            EcoEmptyState(
                icon: .iconMapHero,
                title: "기록을 불러오지 못했어요",
                message: "잠시 후 다시 시도해 주세요",
                action: .init(title: "다시 시도", perform: viewModel.retry)
            )
        }
    }
}

/// Figma `07 활동 기록 · 로딩` (514:303). 홈 로딩과 같은 스켈레톤이다.
private struct ActivityRecordsLoadingView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxl) {
            Text("활동 기록")
                .ecoFont(.title1)
                .foregroundStyle(Color.ecoTextSub)
            EcoSkeleton(kind: .shortLine)
            EcoSkeleton(kind: .card)
            EcoSkeleton(kind: .row)
            EcoSkeleton(kind: .row)
            EcoSkeleton(kind: .longLine)
            Text("불러오는 중이에요")
                .ecoFont(.captionRegular)
                .foregroundStyle(Color.ecoTextSub)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.screenHorizontal)
        // 제목은 불러온 화면(`07 활동 기록` 240:3)과 같은 자리에 둔다. Figma 로딩 프레임(514:303)대로 24를 띄우면
        // 불러오기를 마칠 때 제목과 화면 전체가 위로 튀어오른다(#89).
        .padding(.top, Spacing.lg)
        .accessibilityElement(children: .combine)
    }
}

private extension ActivityRecord.Result {
    var chipStatus: StatusChip.Status {
        switch self {
        case .reviewing: .processing
        case .approved: .approved
        case .rejected: .rejected
        case .notSubmitted: .notSubmitted
        }
    }
}

private func recordsPreview(_ scenario: MockActivityRepository.Scenario, delay: Duration = .zero) -> some View {
    ActivityRecordsView(
        viewModel: DIContainer.preview().makeActivityRecordsViewModel(
            repository: MockActivityRepository(scenario: scenario, delay: delay, now: { MockActivityRepository.Fixture.today }),
            now: { MockActivityRepository.Fixture.today }
        ),
        actions: .init(verify: {})
    )
}

#Preview("기록") { recordsPreview(.records) }
#Preview("빈 상태") { recordsPreview(.empty) }
#Preview("조회 실패") { recordsPreview(.failure) }
#Preview("로딩") { recordsPreview(.records, delay: .seconds(3600)) }
#Preview("월 선택 팝업") {
    ZStack {
        recordsPreview(.records)
        Color.ecoDim.ignoresSafeArea()
        EcoMonthPickerDialog(
            selection: MockActivityRepository.Fixture.month,
            range: DIContainer.activityRecordsEarliestMonth...MockActivityRepository.Fixture.month,
            yearTitle: { ActivityRecordsFormatter.year($0) },
            monthTitle: { ActivityRecordsFormatter.monthOnly($0) },
            onApply: { _ in },
            onCancel: {}
        )
        .padding(.horizontal, Spacing.screenHorizontal)
    }
}
