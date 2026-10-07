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
    /// 새로고침 중에 다시 요청되면 끝난 뒤 한 번 더 조회한다(인증 직후 복귀처럼 진행 중 응답보다 새 데이터가 필요할 때).
    private var hasPendingRefresh = false
    /// 마지막으로 확인한 "이번 달". 앱을 켜 둔 채 달이 바뀌었는지 알아내는 데 쓴다.
    private var lastCurrentMonth: YearMonth

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
        let current = Self.month(containing: now())
        selectedMonth = current
        lastCurrentMonth = current
    }

    /// 이번 달을 보고 있는지. 빈 상태에서 인증으로 보낼지 정한다.
    var isCurrentMonthSelected: Bool {
        selectedMonth == currentMonth
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
        } catch {
            guard id == requestID else { return }
            // 탭을 떠나 취소되면 이전 화면으로 돌린다. 처음 불러오던 중이었다면 .loading으로 남겨 돌아왔을 때 다시 불러온다.
            guard !Task.isCancelled else {
                state = previous
                return
            }
            logError(error)
            state = .failed
        }
    }

    /// 화면을 그대로 둔 채 다시 조회한다(당겨서 새로고침, 인증 후 복귀). 실패하면 지금 화면을 유지한다.
    /// 진행 중에 다시 불리면 끝난 뒤 한 번 더 조회한다.
    func refresh() async {
        guard case .loaded = state else {
            await load()
            return
        }
        guard !isRefreshing else {
            hasPendingRefresh = true
            return
        }
        isRefreshing = true
        defer {
            isRefreshing = false
            hasPendingRefresh = false
        }
        repeat {
            hasPendingRefresh = false
            let id = requestID
            do {
                let result = try await fetchActivityMonthUseCase.execute(selectedMonth)
                // 달을 바꿨거나 처음부터 다시 불렀으면 이 응답과 남은 요청은 버린다.
                guard id == requestID else { return }
                state = .loaded(result)
            } catch {
                guard !Task.isCancelled else { return }
                logError(error)
            }
        } while hasPendingRefresh
    }

    /// 기록 탭 진입·앱 복귀 때 부른다. 그사이 달이 바뀌었고 이전 "이번 달"을 보고 있었다면 새 이번 달로 옮겨 처음부터 불러오고,
    /// 아니면 보던 달을 새로고침한다. 불러오는 중이면 화면의 `.task`가 맡으므로 두고 본다.
    func refreshOnReturn() async {
        let current = currentMonth
        let previous = lastCurrentMonth
        lastCurrentMonth = current
        if current != previous, selectedMonth == previous {
            selectMonth(current)
            return
        }
        guard state != .loading else { return }
        await refresh()
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
