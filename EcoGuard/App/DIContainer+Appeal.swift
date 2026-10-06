import Foundation

extension DIContainer {
    /// 이의신청 작성·제출 실패.
    /// 실제 저장소는 접수 여부를 서버 내역으로 확인하므로 작성·내역이 각자 저장소를 만들어도 된다.
    func makeAppealFormViewModel(
        target: AppealTarget,
        repository: AppealRepository? = nil,
        phase: AppealFormViewModel.Phase = .editing
    ) -> AppealFormViewModel {
        AppealFormViewModel(
            target: target,
            submitAppealUseCase: SubmitAppealUseCase(appealRepository: repository ?? makeAppealRepository()),
            phase: phase
        )
    }

    /// 이의신청 작성의 `사진 다시 찍기`.
    func makeAppealPhotoCaptureViewModel() -> AppealPhotoCaptureViewModel {
        let (camera, permission) = makeCamera()
        return AppealPhotoCaptureViewModel(camera: camera, permission: permission)
    }

    /// 이의신청 내역.
    func makeAppealHistoryViewModel(
        repository: AppealRepository? = nil
    ) -> AppealHistoryViewModel {
        AppealHistoryViewModel(fetchAppealsUseCase: FetchAppealsUseCase(appealRepository: repository ?? makeAppealRepository()))
    }

    private func makeAppealRepository() -> AppealRepository {
        apiClient.map { AppealRepositoryImpl(apiClient: $0) } ?? MockAppealRepository()
    }
}
