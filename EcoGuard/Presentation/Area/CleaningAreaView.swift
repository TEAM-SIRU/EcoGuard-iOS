import SwiftUI

/// Figma `05 청소구역` (239:3) · `06 청소구역 · 미배정` (246:145) · `05 청소구역 · 조회 실패` (317:1225) · `05 청소구역 · 로딩` (514:278).
struct CleaningAreaView: View {
    let viewModel: CleaningAreaViewModel

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.ecoCard)
            .task {
                // 불러온 화면이 없으면(처음, 탭을 떠나 취소됨) 다시 불러온다. 실패 화면은 사용자가 다시 시도한다.
                guard viewModel.state == .loading else { return }
                await viewModel.load()
            }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            CleaningAreaLoadingView()
        case .failed:
            messageLayout {
                EcoEmptyState(
                    icon: .iconMapHero,
                    title: "도면을 불러오지 못했어요",
                    message: "인터넷 연결을 확인하고 다시 시도해 주세요",
                    action: .init(title: "다시 시도", perform: viewModel.load)
                )
            }
        case .loaded(.unassigned):
            messageLayout {
                EcoEmptyState(
                    icon: .iconMapHero,
                    title: "아직 배정된 구역이 없어요",
                    message: "선생님이 구역을 배정하면 여기에 보여요"
                )
            }
            .refreshable { await viewModel.refresh() }
        case .loaded(.assigned(let floors, _, let area)):
            assignedView(floors: floors, area: area)
        }
    }

    /// 제목만 위에 두고 안내를 가운데에 놓는다. 당겨서 새로고침이 되도록 스크롤 안에 둔다.
    private func messageLayout(@ViewBuilder _ message: () -> some View) -> some View {
        let message = message()
        return GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    title
                    message
                }
                .frame(minHeight: proxy.size.height)
            }
        }
    }

    private var title: some View {
        Text("내 청소 구역")
            .ecoFont(.title1)
            .foregroundStyle(Color.ecoTextPrimary)
            .accessibilityAddTraits(.isHeader)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.xl)
    }

    private func assignedView(floors: [FloorPlan], area: MyCleaningArea) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                EcoPageHeader(title: "내 청소 구역", subtitle: subtitle)
                    .padding(.top, Spacing.sm)
                EcoSegmentedControl(
                    items: floors.map { .init(id: $0.id, title: $0.name) },
                    selection: viewModel.selectedFloor?.id,
                    onSelect: viewModel.selectFloor(id:)
                )
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.bottom, Spacing.lg)
                if let floor = viewModel.selectedFloor {
                    FloorPlanGrid(floor: floor)
                        .padding(.horizontal, Spacing.screenHorizontal)
                        .padding(.top, Spacing.xs)
                        .padding(.bottom, Spacing.xxl)
                }
                HStack(spacing: Spacing.lg) {
                    EcoAreaLegendItem(style: .mine)
                    EcoAreaLegendItem(style: .cleaning)
                    EcoAreaLegendItem(style: .notCleaning)
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.top, Spacing.xs)
                .padding(.bottom, Spacing.xl)
                Rectangle()
                    .fill(Color.ecoDivider)
                    .frame(height: Spacing.md)
                    .accessibilityHidden(true)
                EcoListRow(icon: nil, title: area.range, subtitle: "구역 설명 · \(area.description)", horizontalPadding: Spacing.screenHorizontal)
                EcoListRow(icon: nil, title: "매일 \(CleaningAreaFormatter.window(area))", subtitle: "청소 시간", horizontalPadding: Spacing.screenHorizontal)
                EcoListRow(
                    icon: nil,
                    title: "\(area.memberNames.count)명이 함께해요",
                    subtitle: CleaningAreaFormatter.members(area),
                    horizontalPadding: Spacing.screenHorizontal
                )
            }
            .padding(.bottom, Spacing.xxl)
        }
        .refreshable { await viewModel.refresh() }
    }

    private var subtitle: LocalizedStringKey {
        "내 구역은 핀과 테두리로 표시돼요 · \(viewModel.selectedFloor?.name ?? "") 선택됨"
    }
}

/// 한 층 도면. 줄마다 칸이 `span` 비율로 폭을 나눈다(Figma 복도 2 : 나머지 1).
private struct FloorPlanGrid: View {
    let floor: FloorPlan

    var body: some View {
        VStack(spacing: Spacing.sm) {
            ForEach(Array(floor.rows.enumerated()), id: \.offset) { _, row in
                SpanRow(spacing: Spacing.sm) {
                    ForEach(row) { cell in
                        EcoAreaCell(name: cell.name, style: cell.kind.cellStyle)
                            .layoutValue(key: SpanKey.self, value: cell.span)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(verbatim: "\(floor.name) 도면"))
    }
}

private struct SpanKey: LayoutValueKey {
    static let defaultValue = 1
}

/// 자식 폭을 `SpanKey` 비율로 나누는 가로 배치.
private struct SpanRow: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.replacingUnspecifiedDimensions().width
        let height = subviews.indices.map { subviews[$0].sizeThatFits(.init(width: cellWidth(at: $0, total: width, subviews: subviews), height: nil)).height }.max() ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        for index in subviews.indices {
            let width = cellWidth(at: index, total: bounds.width, subviews: subviews)
            subviews[index].place(at: CGPoint(x: x, y: bounds.minY), proposal: .init(width: width, height: bounds.height))
            x += width + spacing
        }
    }

    private func cellWidth(at index: Int, total: CGFloat, subviews: Subviews) -> CGFloat {
        let spans = subviews.map { max($0[SpanKey.self], 1) }
        let available = max(0, total - spacing * CGFloat(max(subviews.count - 1, 0)))
        return available * CGFloat(spans[index]) / CGFloat(spans.reduce(0, +))
    }
}

/// Figma `05 청소구역 · 로딩` (514:278).
private struct CleaningAreaLoadingView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxl) {
            Text("내 청소 구역")
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
        .padding(.top, Spacing.xxl)
        .accessibilityElement(children: .combine)
    }
}

private extension FloorPlanCell.Kind {
    var cellStyle: EcoAreaCell.Style {
        switch self {
        case .mine: .mine
        case .cleaning: .cleaning
        case .notCleaning: .notCleaning
        }
    }
}

enum CleaningAreaFormatter {
    /// "08:00 – 08:10"
    static func window(_ area: MyCleaningArea) -> String {
        "\(HomeFormatter.time(minuteOfDay: area.startMinute)) – \(HomeFormatter.time(minuteOfDay: area.endMinute))"
    }

    /// "김서연 · 이도윤 · 나(최민준)". 나는 맨 뒤에 둔다.
    static func members(_ area: MyCleaningArea) -> String {
        let others = area.memberNames.filter { $0 != area.myName }
        return (others + ["나(\(area.myName))"]).joined(separator: " · ")
    }
}

private func areaPreview(_ scenario: MockCleaningAreaRepository.Scenario) -> some View {
    CleaningAreaView(viewModel: DIContainer.preview().makeCleaningAreaViewModel(
        repository: MockCleaningAreaRepository(scenario: scenario, delay: .zero)
    ))
}

#Preview("배정됨") { areaPreview(.assigned) }
#Preview("미배정") { areaPreview(.unassigned) }
#Preview("조회 실패") { areaPreview(.failure) }
#Preview("로딩") {
    CleaningAreaView(viewModel: DIContainer.preview().makeCleaningAreaViewModel(
        repository: MockCleaningAreaRepository(scenario: .assigned, delay: .seconds(3600))
    ))
}
