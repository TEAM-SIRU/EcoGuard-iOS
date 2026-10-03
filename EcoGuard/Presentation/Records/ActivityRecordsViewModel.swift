import Foundation
import Observation
import os

@Observable
@MainActor
final class ActivityRecordsViewModel {
    enum State: Equatable {
        case loading
        case loaded(ActivityMonth)
        case failed
    }

    private(set) var state: State
    /// 보고 있는 달. 처음에는 오늘(KST)이 속한 달이다.
    private(set) var selectedMonth: YearMonth

    private let fetchActivityMonthUseCase: FetchActivityMonthUseCase
    private let now: () -> Date
    /// 고를 수 있는 가장 이른 달(서비스 시작).
    private let earliestMonth: YearMonth
    private let logger = Logger(subsystem: "EcoGuard", category: "ActivityRecords")
    /// 조회마다 올린다. 응답이 왔을 때 값이 바뀌었으면(달을 바꿨거나 다시 불렀으면) 그 응답은 버린다.
    private var requestID = 0
    private var isRefreshing = false

    init(
        fetchActivityMonthUseCase: FetchActivityMonthUseCase,
        earliestMonth: YearMonth,
        now: @escaping () -> Date = Date.init,
        state: State = .loading
    ) {
        self.fetchActivityMonthUseCase = fetchActivityMonthUseCase
        self.earliestMonth = earliestMonth
        self.now = now
        self.state = state
        selectedMonth = Self.month(containing: now())
    }

    /// 오늘이 속한 달. 이후 달은 고를 수 없다.
    var currentMonth: YearMonth {
        Self.month(containing: now())
    }

    /// 월 선택 팝업에서 고를 수 있는 범위.
    var selectableMonths: ClosedRange<YearMonth> {
        earliestMonth...max(earliestMonth, currentMonth)
    }

    /// 기록 목록의 주 묶음. 오늘(KST) 기준으로 나눈다.
    var sections: [ActivityWeekSection] {
        guard case .loaded(let month) = state else { return [] }
        return ActivityRecordsFormatter.sections(for: month, today: now())
    }

    /// 스켈레톤을 보여 주며 고른 달을 처음부터 불러온다.
    func load() async {
        requestID += 1
        let id = requestID
        let month = selectedMonth
        let previous = state
        state = .loading
        do {
            let result = try await fetchActivityMonthUseCase.execute(month)
            guard id == requestID else { return }
            state = .loaded(result)
        } catch is CancellationError {
            // 화면을 떠나 취소되면 .loading에 남지 않게 이전 화면으로 돌린다. 처음 불러오던 중이었다면 다시 시도할 수 있게 실패로 둔다.
            guard id == requestID else { return }
            state = previous == .loading ? .failed : previous
        } catch {
            guard id == requestID else { return }
            logError(error)
            state = .failed
        }
    }

    /// 화면을 그대로 둔 채 다시 조회한다(당겨서 새로고침, 인증 후 복귀). 실패하면 지금 화면을 유지한다.
    func refresh() async {
        guard case .loaded = state else {
            await load()
            return
        }
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        let id = requestID
        do {
            let result = try await fetchActivityMonthUseCase.execute(selectedMonth)
            guard id == requestID else { return }
            state = .loaded(result)
        } catch is CancellationError {
            return
        } catch {
            logError(error)
        }
    }

    func retry() async {
        await load()
    }

    /// 다른 달을 고른다. 진행 중인 조회 결과는 버리고 스켈레톤으로 바꾼다. 실제 조회는 화면이 `selectedMonth` 변화를 보고 `load()`로 한다.
    func selectMonth(_ month: YearMonth) {
        guard month != selectedMonth, selectableMonths.contains(month) else { return }
        requestID += 1
        selectedMonth = month
        state = .loading
    }

    private func logError(_ error: Error) {
        logger.error("활동 기록 조회 실패: \(String(describing: type(of: error)), privacy: .public) \(String(describing: error), privacy: .private)")
    }

    private static func month(containing date: Date) -> YearMonth {
        let components = ActivityRecordsFormatter.calendar.dateComponents([.year, .month], from: date)
        return YearMonth(year: components.year ?? 0, month: components.month ?? 0)
    }
}
