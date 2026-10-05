import Foundation
import Testing
@testable import EcoGuard

@MainActor
struct AppealFormViewModelTests {
    private typealias Fixture = MockAppealRepository.Fixture
    private let message = "복도 끝도 청소했는데 사진에서 잘렸어요"

    private func makeViewModel(
        _ submitOutcomes: [MockAppealRepository.SubmitOutcome] = [.success],
        delay: Duration = .zero,
        message: String? = nil
    ) -> (AppealFormViewModel, MockAppealRepository) {
        let repository = MockAppealRepository(submitOutcomes: submitOutcomes, delay: delay)
        let viewModel = AppealFormViewModel(
            target: Fixture.target,
            submitAppealUseCase: SubmitAppealUseCase(appealRepository: repository),
            requestID: "request-1"
        )
        viewModel.message = message ?? self.message
        return (viewModel, repository)
    }

    @Test func submitSendsTrimmedMessageAndPhotosAsNextRound() async throws {
        let (viewModel, repository) = makeViewModel(message: "  \(message)\n")
        viewModel.addPhoto(Data([1]))

        let appeal = try #require(await viewModel.submit())

        #expect(viewModel.phase == .editing)
        #expect(repository.submitCallCount == 1)
        #expect(repository.statusCheckCallCount == 0)
        #expect(repository.lastDraft?.message == message)
        #expect(repository.lastDraft?.photos == viewModel.photos)
        #expect(repository.lastDraft?.requestID == "request-1")
        // Fixture 내역에 같은 인증의 1·2차가 있어 3차가 된다.
        #expect(appeal.round == 3)
        #expect(appeal.status == .reviewing)
        #expect(appeal.verifiedAt == Fixture.rejectedVerifiedAt)
    }

    /// 인자는 MainActor 밖에서 만들어져 `AppealMessage.maxLength`(300)를 쓰지 못한다.
    @Test(arguments: ["", "  \n ", String(repeating: "가", count: 301)])
    func invalidMessageDoesNotSubmit(text: String) async {
        let (viewModel, repository) = makeViewModel(message: text)

        #expect(await viewModel.submit() == nil)
        #expect(viewModel.canSubmit == false)
        #expect(repository.submitCallCount == 0)
    }

    /// 실제 서버 모드: 서버가 이의신청 사진을 받지 않아 사진을 붙이지 않는다.
    @Test func photosDisabledIgnoresAddPhoto() {
        let viewModel = AppealFormViewModel(
            target: Fixture.target,
            submitAppealUseCase: SubmitAppealUseCase(appealRepository: MockAppealRepository(delay: .zero)),
            allowsPhotos: false
        )

        viewModel.addPhoto(Data([1]))

        #expect(!viewModel.canAddPhoto)
        #expect(viewModel.photos.isEmpty)
    }

    @Test func messageAtMaxLengthIsValid() {
        let (viewModel, _) = makeViewModel(message: String(repeating: "가", count: AppealMessage.maxLength))

        #expect(viewModel.validation == .valid)
    }

    @Test func failureKeepsInputAndShowsFailure() async {
        let (viewModel, _) = makeViewModel([.failure])
        viewModel.addPhoto(Data([1]))

        #expect(await viewModel.submit() == nil)

        #expect(viewModel.phase == .failed)
        #expect(viewModel.message == message)
        #expect(viewModel.photos.count == 1)
    }

    @Test func retryChecksPreviousSubmissionThenSends() async throws {
        let (viewModel, repository) = makeViewModel([.failure, .success])
        _ = await viewModel.submit()

        let appeal = try #require(await viewModel.retry())

        #expect(viewModel.phase == .editing)
        #expect(repository.statusCheckCallCount == 1)
        #expect(repository.submitCallCount == 2)
        #expect(appeal.round == 3)
    }

    @Test func retryDoesNotResendWhenServerAlreadyReceived() async throws {
        let (viewModel, repository) = makeViewModel([.failureAfterReceived, .success])
        _ = await viewModel.submit()
        #expect(viewModel.phase == .failed)

        let appeal = try #require(await viewModel.retry())

        // 앞선 제출이 접수됐으므로 다시 보내지 않고 그 결과로 완료한다(중복 접수 방지).
        #expect(repository.statusCheckCallCount == 1)
        #expect(repository.submitCallCount == 1)
        #expect(appeal.id == "appeal-request-1")
        #expect(viewModel.phase == .editing)
    }

    @Test func retryFailureStaysOnFailure() async {
        let (viewModel, repository) = makeViewModel([.failure])
        _ = await viewModel.submit()

        #expect(await viewModel.retry() == nil)

        #expect(viewModel.phase == .failed)
        #expect(repository.submitCallCount == 2)
    }

    @Test func editAfterFailureReturnsToEditorWithInput() async {
        let (viewModel, _) = makeViewModel([.failure])
        _ = await viewModel.submit()

        viewModel.editAfterFailure()

        #expect(viewModel.phase == .editing)
        #expect(viewModel.message == message)
    }

    @Test func editedResubmitAfterReceivedFailureShowsAlreadyReceived() async throws {
        let (viewModel, repository) = makeViewModel([.failureAfterReceived, .success])
        _ = await viewModel.submit()
        viewModel.editAfterFailure()
        viewModel.message = "내용을 고쳤어요"

        // 처음 내용이 이미 접수됐으므로 고친 내용을 보내지 않고(중복 접수 방지) 반영되지 않았다고 안내한다.
        #expect(await viewModel.submit() == nil)

        #expect(repository.statusCheckCallCount == 1)
        #expect(repository.submitCallCount == 1)
        #expect(viewModel.isShowingAlreadyReceived)
        let appeal = try #require(viewModel.alreadyReceivedAppeal)
        #expect(appeal.id == "appeal-request-1")
        #expect(viewModel.phase == .editing)

        viewModel.confirmAlreadyReceived()

        #expect(viewModel.isShowingAlreadyReceived == false)
        #expect(viewModel.alreadyReceivedAppeal == appeal)
    }

    @Test func resubmitWithSameContentAfterReceivedFailureCompletes() async throws {
        let (viewModel, repository) = makeViewModel([.failureAfterReceived, .success])
        _ = await viewModel.submit()
        viewModel.editAfterFailure()
        viewModel.message = "내용을 고쳤어요"
        viewModel.message = message

        let appeal = try #require(await viewModel.submit())

        #expect(appeal.id == "appeal-request-1")
        #expect(repository.submitCallCount == 1)
        #expect(viewModel.isShowingAlreadyReceived == false)
        #expect(viewModel.alreadyReceivedAppeal == nil)
    }

    @Test func editedPhotosAfterReceivedFailureShowsAlreadyReceived() async {
        let (viewModel, repository) = makeViewModel([.failureAfterReceived, .success])
        _ = await viewModel.submit()
        viewModel.editAfterFailure()
        viewModel.addPhoto(Data([1]))

        #expect(await viewModel.submit() == nil)

        #expect(repository.submitCallCount == 1)
        #expect(viewModel.isShowingAlreadyReceived)
    }

    @Test func editedResubmitAfterUnreceivedFailureSendsNewContent() async throws {
        let (viewModel, repository) = makeViewModel([.failure, .success])
        _ = await viewModel.submit()
        viewModel.editAfterFailure()
        viewModel.message = "내용을 고쳤어요"

        _ = try #require(await viewModel.submit())

        #expect(repository.statusCheckCallCount == 1)
        #expect(repository.submitCallCount == 2)
        #expect(repository.lastDraft?.message == "내용을 고쳤어요")
        #expect(repository.lastDraft?.requestID == "request-1")
        #expect(viewModel.isShowingAlreadyReceived == false)
    }

    @Test func submitWhileSubmittingIsIgnored() async {
        let (viewModel, repository) = makeViewModel(delay: .milliseconds(200))

        let first = Task { await viewModel.submit() }
        try? await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.phase == .submitting)
        #expect(viewModel.isSubmitting)

        #expect(await viewModel.submit() == nil)
        #expect(await viewModel.retry() == nil)
        _ = await first.value

        #expect(repository.submitCallCount == 1)
    }

    @Test func retryWhileRetryingIsIgnored() async {
        let (viewModel, repository) = makeViewModel([.failure, .success])
        _ = await viewModel.submit()
        repository.delay = .milliseconds(200)

        let first = Task { await viewModel.retry() }
        try? await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.phase == .retrying)

        #expect(await viewModel.retry() == nil)
        #expect(await viewModel.submit() == nil)
        _ = await first.value

        #expect(repository.submitCallCount == 2)
    }

    @Test func cancelledSubmitReturnsToEditorAndChecksNextTime() async throws {
        let (viewModel, repository) = makeViewModel(delay: .seconds(10))

        let task = Task { await viewModel.submit() }
        try? await Task.sleep(for: .milliseconds(50))
        task.cancel()
        #expect(await task.value == nil)

        // 화면을 떠나 취소된 것은 실패 화면이 아니다. 서버에 닿았을 수 있어 다음 제출은 먼저 확인한다.
        #expect(viewModel.phase == .editing)

        repository.delay = .zero
        _ = try #require(await viewModel.submit())

        #expect(repository.statusCheckCallCount == 1)
        #expect(repository.submitCallCount == 2)
        #expect(viewModel.phase == .editing)
    }

    @Test func cancelledRetryStaysOnFailure() async {
        let (viewModel, repository) = makeViewModel([.failure])
        _ = await viewModel.submit()
        repository.delay = .seconds(10)

        let task = Task { await viewModel.retry() }
        try? await Task.sleep(for: .milliseconds(50))
        task.cancel()
        _ = await task.value

        #expect(viewModel.phase == .failed)
    }

    @Test func photosAreLimitedAndRemovable() throws {
        let (viewModel, _) = makeViewModel()
        for byte in 0..<(AppealMessage.maxPhotoCount + 1) {
            viewModel.addPhoto(Data([UInt8(byte)]))
        }

        #expect(viewModel.photos.count == AppealMessage.maxPhotoCount)
        #expect(viewModel.canAddPhoto == false)

        let first = try #require(viewModel.photos.first)
        viewModel.removePhoto(id: first.id)

        #expect(viewModel.photos.count == AppealMessage.maxPhotoCount - 1)
        #expect(viewModel.photos.contains(first) == false)
        #expect(viewModel.canAddPhoto)
    }

    @Test func photosCannotChangeWhileSubmitting() async throws {
        let (viewModel, _) = makeViewModel(delay: .milliseconds(200))
        viewModel.addPhoto(Data([1]))
        let photo = try #require(viewModel.photos.first)

        let task = Task { await viewModel.submit() }
        try? await Task.sleep(for: .milliseconds(50))
        viewModel.addPhoto(Data([2]))
        viewModel.removePhoto(id: photo.id)
        _ = await task.value

        #expect(viewModel.photos == [photo])
    }
}
