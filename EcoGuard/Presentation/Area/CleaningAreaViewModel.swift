import Foundation
import Observation
import os

@Observable
@MainActor
final class CleaningAreaViewModel {
    enum State: Equatable {
        case loading
        case loaded(CleaningAreaSummary)
        case failed
    }

    private(set) var state: State
    /// 도면에서 보고 있는 층. 처음 불러오면 내 구역이 있는 층을 고른다.
    private(set) var selectedFloorID: String?

    private let fetchCleaningAreaUseCase: FetchCleaningAreaUseCase
    private let logger = Logger(subsystem: "EcoGuard", category: "CleaningArea")
    private var isFetching = false

    init(fetchCleaningAreaUseCase: FetchCleaningAreaUseCase, state: State = .loading) {
        self.fetchCleaningAreaUseCase = fetchCleaningAreaUseCase
        self.state = state
        if case .loaded(let summary) = state {
            selectedFloorID = summary.myFloorID
        }
    }

    /// 지금 보고 있는 층의 도면.
    var selectedFloor: FloorPlan? {
        guard case .loaded(.assigned(let floors, _, _)) = state else { return nil }
        return floors.first { $0.id == selectedFloorID } ?? floors.first
    }

    /// 스켈레톤을 보여 주며 처음부터 불러온다.
    func load() async {
        guard !isFetching else { return }
        isFetching = true
        defer { isFetching = false }
        let previous = state
        state = .loading
        do {
            apply(try await fetchCleaningAreaUseCase.execute())
        } catch is CancellationError {
            state = previous == .loading ? .failed : previous
        } catch {
            logError(error)
            state = .failed
        }
    }

    /// 화면을 그대로 둔 채 다시 조회한다(당겨서 새로고침). 실패하면 지금 화면을 유지한다.
    func refresh() async {
        guard case .loaded = state else {
            await load()
            return
        }
        guard !isFetching else { return }
        isFetching = true
        defer { isFetching = false }
        do {
            apply(try await fetchCleaningAreaUseCase.execute())
        } catch is CancellationError {
            return
        } catch {
            logError(error)
        }
    }

    func selectFloor(id: String) {
        guard case .loaded(.assigned(let floors, _, _)) = state, floors.contains(where: { $0.id == id }) else { return }
        selectedFloorID = id
    }

    private func apply(_ summary: CleaningAreaSummary) {
        state = .loaded(summary)
        // 고른 층이 새 도면에도 있으면 유지하고, 없으면 내 구역 층으로 돌아간다.
        if case .assigned(let floors, let myFloorID, _) = summary {
            if !floors.contains(where: { $0.id == selectedFloorID }) {
                selectedFloorID = myFloorID
            }
        } else {
            selectedFloorID = nil
        }
    }

    private func logError(_ error: Error) {
        logger.error("청소 구역 조회 실패: \(String(describing: type(of: error)), privacy: .public) \(String(describing: error), privacy: .private)")
    }
}

private extension CleaningAreaSummary {
    var myFloorID: String? {
        if case .assigned(_, let myFloorID, _) = self { return myFloorID }
        return nil
    }
}
