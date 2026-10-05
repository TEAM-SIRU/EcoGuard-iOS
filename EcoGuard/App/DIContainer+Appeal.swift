import Foundation

extension DIContainer {
    /// 이의신청 작성·제출 실패.
    // TODO: 서버 연동 때 저장소를 DIContainer 프로퍼티로 옮기고 실제 구현으로 바꾼다. 작성·내역이 같은 저장소를 써야 한다.
    func makeAppealFormViewModel(
        target: AppealTarget,
        repository: AppealRepository = MockAppealRepository(),
        phase: AppealFormViewModel.Phase = .editing
    ) -> AppealFormViewModel {
        AppealFormViewModel(
            target: target,
            submitAppealUseCase: SubmitAppealUseCase(appealRepository: repository),
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
        repository: AppealRepository = MockAppealRepository()
    ) -> AppealHistoryViewModel {
        AppealHistoryViewModel(fetchAppealsUseCase: FetchAppealsUseCase(appealRepository: repository))
    }
}
