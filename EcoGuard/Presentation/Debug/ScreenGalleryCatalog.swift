#if DEBUG
import SwiftUI

struct ScreenGalleryItem: Identifiable {
    /// 실행 인자 `-ScreenGallery <id>`로 바로 열 때 쓴다.
    let id: String
    let title: String
    /// 화면을 만든다. `close`는 화면 모음 목록으로 돌아간다.
    let makeContent: (_ close: @escaping () -> Void) -> AnyView
}

struct ScreenGallerySection: Identifiable {
    let title: String
    let items: [ScreenGalleryItem]

    var id: String { title }
}

/// 화면 모음 항목. 모든 화면은 실서버 설정과 상관없이 Mock 저장소만 쓴다.
/// ViewModel 상태를 넣을 수 있는 화면은 상태를 넣고, 아니면 Mock 저장소 시나리오로 그 상태를 만든다.
enum ScreenGalleryCatalog {
    static var sections: [ScreenGallerySection] {
        [shell, login, recruitment, verification, verificationResult, appeal, notice, myPage, areaAndRecords, components]
    }

    /// Mock 저장소 기본 지연(`DIContainer.live()`의 Mock 구성과 같다).
    private static let mockDelay: Duration = .seconds(1)
    /// 로딩 화면을 계속 보여 줄 때.
    private static let loadingDelay: Duration = .seconds(3600)

    // MARK: - ① 탭 셸

    private static var shell: ScreenGallerySection {
        ScreenGallerySection(title: "탭 셸 (Mock 로그인 · 홈 상태)", items: [
            shellItem("shell.notSubmitted", "활동 중 · 인증 가능", home: .notSubmitted),
            shellItem("shell.notOpenYet", "활동 중 · 인증 시간 아님(마감 후·시작 전)", home: .notOpenYet),
            shellItem("shell.aiReviewing", "활동 중 · 제출함(AI 검수 중)", home: .aiReviewing),
            shellItem("shell.teacherReviewing", "활동 중 · 제출함(선생님 확인 중)", home: .teacherReviewing),
            shellItem("shell.approved", "활동 중 · 승인", home: .approved),
            shellItem("shell.rejected", "활동 중 · 반려", home: .rejected),
            shellItem("shell.vacation", "방학", home: .vacation),
            shellItem("shell.recruiting", "모집 중(미가입)", home: .recruiting),
            shellItem("shell.awaitingAssignment", "배정 대기", home: .awaitingAssignment),
            shellItem("shell.excluded", "활동 제외", home: .excluded),
            shellItem("shell.notSelected", "미선발", home: .notSelected),
            shellItem("shell.notRecruiting", "모집 없음", home: .notRecruiting),
            shellItem("shell.failure", "홈 조회 실패", home: .failure),
            shellItem("shell.loading", "홈 로딩", home: .notSubmitted, homeDelay: loadingDelay)
        ])
    }

    private static func shellItem(
        _ id: String,
        _ title: String,
        home: MockHomeRepository.Scenario,
        homeDelay: Duration = mockDelay
    ) -> ScreenGalleryItem {
        item(id, title) { close in
            let container = container(home: home, homeDelay: homeDelay)
            MainTabView(container: container, homeViewModel: container.makeHomeViewModel(), onLoggedOut: close)
        }
    }

    // MARK: - ② 로그인

    private static var login: ScreenGallerySection {
        ScreenGallerySection(title: "로그인", items: [
            item("login.idle", "기본") { _ in
                LoginView(viewModel: container().makeLoginViewModel(state: .idle))
            },
            item("login.loading", "로딩") { _ in
                LoginView(viewModel: container().makeLoginViewModel(state: .loading))
            },
            item("login.failed", "실패") { _ in
                LoginView(viewModel: container(authOutcome: .failure).makeLoginViewModel(state: .failed))
            },
            item("login.teacher", "교사 안내 · 웹 주소 있음") { close in
                // example.com은 문서용 예약 도메인이다.
                TeacherNoticeView(webAdminURL: AppConfig.webAdminURL(from: "https://example.com")) { close() }
            },
            item("login.teacherNoURL", "교사 안내 · 웹 주소 없음") { close in
                TeacherNoticeView(webAdminURL: nil) { close() }
            }
        ])
    }

    // MARK: - ③ 모집

    private static var recruitment: ScreenGallerySection {
        ScreenGallerySection(title: "모집 (공고 · 신청 · 결과)", items: [
            recruitmentFlow("recruitment.open", "공고 · 모집 중"),
            recruitmentFlow("recruitment.full", "공고 · 정원 마감", scenario: .full),
            recruitmentFlow("recruitment.applied", "공고 · 이미 신청", scenario: .applied),
            recruitmentFlow("recruitment.upcoming", "공고 · 신청 기간 전", scenario: .upcoming),
            recruitmentFlow("recruitment.ended", "공고 · 신청 기간 끝", scenario: .ended),
            recruitmentFlow("recruitment.none", "공고 없음", scenario: .none),
            recruitmentFlow("recruitment.failure", "공고 조회 실패", scenario: .failure),
            recruitmentFlow("recruitment.loading", "공고 로딩", delay: loadingDelay),
            recruitmentApply("recruitment.apply", "신청서 → 승인(배정 대기)"),
            recruitmentApply("recruitment.applyAssigned", "신청서 → 승인(배정 완료)", applyOutcomes: [.approvedAndAssigned]),
            recruitmentApply("recruitment.applyRetry", "신청서 · 실패 후 재시도", applyOutcomes: [.failure, .approved]),
            recruitmentApply("recruitment.applyFull", "신청서 · 신청 중 정원 초과", applyOutcomes: [.full]),
            recruitmentApply("recruitment.applyNotInPeriod", "신청서 · 신청 중 기간 종료", applyOutcomes: [.notInPeriod]),
            applicationResult("recruitment.result.applied", "신청 결과 · 승인(배정 대기)", outcome: .applied(seededApplication(isAreaAssigned: false))),
            applicationResult("recruitment.result.assigned", "신청 결과 · 승인(배정 완료)", outcome: .applied(seededApplication(isAreaAssigned: true))),
            applicationResult("recruitment.result.full", "신청 결과 · 신청 중 마감", outcome: .closedWhileApplying(reason: .full)),
            applicationResult("recruitment.result.periodEnded", "신청 결과 · 신청 중 기간 종료", outcome: .closedWhileApplying(reason: .periodEnded)),
            applicationResult("recruitment.result.fetched", "신청 결과 · 내 신청 불러오기", scenario: .applied),
            applicationResult("recruitment.result.notApplied", "신청 결과 · 신청 내역 없음", scenario: .open),
            applicationResult("recruitment.result.failure", "신청 결과 · 조회 실패", scenario: .failure)
        ])
    }

    private static func recruitmentFlow(
        _ id: String,
        _ title: String,
        scenario: MockRecruitmentRepository.Scenario = .open,
        applyOutcomes: [MockRecruitmentRepository.ApplyOutcome] = [.approved],
        delay: Duration = mockDelay
    ) -> ScreenGalleryItem {
        item(id, title) { close in
            RecruitmentFlowView(
                container: container(home: .recruiting, recruitment: scenario, applyOutcomes: applyOutcomes, recruitmentDelay: delay),
                onExit: close,
                goHome: close
            )
        }
    }

    /// 신청서부터 시작해 `RecruitmentFlowView`처럼 신청서 → 결과를 이어 붙인다(공고부터는 `recruitment.open`).
    private static func recruitmentApply(
        _ id: String,
        _ title: String,
        applyOutcomes: [MockRecruitmentRepository.ApplyOutcome] = [.approved]
    ) -> ScreenGalleryItem {
        item(id, title) { close in
            let container = container(home: .recruiting, applyOutcomes: applyOutcomes)
            ScreenGalleryStack { navigator in
                RecruitmentApplyView(
                    viewModel: container.makeRecruitmentApplyViewModel(
                        applicant: MockRecruitmentRepository.Fixture.applicant,
                        capacityPerClass: 6
                    ),
                    onFinish: { outcome in
                        navigator.push(ApplicationResultView(
                            viewModel: container.makeApplicationResultViewModel(outcome: outcome),
                            onBack: close,
                            goHome: close
                        ))
                    }
                )
            }
        }
    }

    /// 이미 신청한 학생의 신청(오늘 기준 공고 기간). `MockStore`가 만든 값과 같다.
    private static func seededApplication(isAreaAssigned: Bool) -> RecruitmentApplication {
        let application = MockStore(homeScenario: .awaitingAssignment).application ?? MockRecruitmentRepository.Fixture.application()
        return RecruitmentApplication(order: application.order, appliedAt: application.appliedAt, isAreaAssigned: isAreaAssigned)
    }

    /// `outcome`이 nil이면 Mock 저장소(`scenario`)에서 내 신청을 불러온다.
    private static func applicationResult(
        _ id: String,
        _ title: String,
        outcome: ApplicationOutcome? = nil,
        scenario: MockRecruitmentRepository.Scenario = .open
    ) -> ScreenGalleryItem {
        item(id, title) { close in
            NavigationStack {
                ApplicationResultView(
                    viewModel: container(home: .recruiting, recruitment: scenario).makeApplicationResultViewModel(outcome: outcome),
                    onBack: close,
                    goHome: close
                )
            }
        }
    }

    // MARK: - ④ 청소 인증

    private static var verification: ScreenGallerySection {
        let submittedAt = MockVerificationRepository.Fixture.submittedAt
        return ScreenGallerySection(title: "청소 인증", items: [
            cameraFlow("verification.flow", "실제 흐름 · 촬영 → 제출"),
            cameraFlow("verification.flowUploadRetry", "실제 흐름 · 업로드 실패 후 재시도", uploadResults: [.networkFailure, .success]),
            cameraFlow("verification.loading", "불러오는 중", delay: loadingDelay),
            cameraFlow("verification.loadFailed", "조회 실패", scenario: .failure),
            camera("verification.guide", "촬영 안내", state: .guide),
            camera("verification.capturing", "촬영", state: .capturing),
            camera("verification.confirming", "확인", state: .confirming(capturedPhoto)),
            camera("verification.uploading", "업로드 중", state: .uploading(capturedPhoto)),
            camera("verification.submitted", "제출 완료 · AI 검수 중", state: .submitted(capturedPhoto, submittedAt: submittedAt)),
            camera("verification.uploadFailed", "업로드 실패", state: .uploadFailed(capturedPhoto)),
            camera("verification.timedOut", "시간 초과", state: .timedOut),
            camera("verification.notAssigned", "구역 미배정", state: .notAssigned),
            camera(
                "verification.sheet.outsideHours",
                "인증 불가 시트 · 인증 시간 아님",
                state: .guide,
                sheet: .outsideWindow(.outsideHours),
                availability: .outsideWindow(.outsideHours)
            ),
            camera(
                "verification.sheet.alreadySubmitted",
                "인증 불가 시트 · 오늘 이미 제출",
                state: .guide,
                sheet: .alreadySubmitted(submittedAt: submittedAt, status: .processing),
                availability: .alreadySubmitted(submittedAt: submittedAt, status: .processing)
            ),
            camera("verification.sheet.permission", "인증 불가 시트 · 카메라 권한 필요", state: .guide, sheet: .permissionRequired),
            camera(
                "verification.sheet.weekend",
                "인증 불가 시트 · 주말",
                state: .guide,
                sheet: .outsideWindow(.weekend),
                availability: .outsideWindow(.weekend)
            ),
            camera(
                "verification.sheet.vacation",
                "인증 불가 시트 · 방학",
                state: .guide,
                sheet: .outsideWindow(.vacation),
                availability: .outsideWindow(.vacation)
            )
        ])
    }

    /// Mock 저장소에서 오늘 인증 정보를 불러오는 실제 흐름.
    private static func cameraFlow(
        _ id: String,
        _ title: String,
        scenario: MockVerificationRepository.Scenario = .open,
        uploadResults: [MockVerificationRepository.UploadResult] = [.success],
        delay: Duration = mockDelay
    ) -> ScreenGalleryItem {
        item(id, title) { close in
            let container = container()
            CameraVerificationView(
                viewModel: container.makeCameraVerificationViewModel(
                    repository: MockVerificationRepository(scenario: scenario, uploadResults: uploadResults, delay: delay, store: container.mockStore)
                ),
                actions: CameraVerificationView.Actions(close: close, goHome: close, openSubmitted: close)
            )
        }
    }

    /// 상태를 바로 넣은 인증 화면. 오늘 인증 정보는 Figma 값(본관 2층 복도 A, 마감 5분 32초 전)이다.
    private static func camera(
        _ id: String,
        _ title: String,
        state: CameraVerificationViewModel.State,
        sheet: CameraVerificationViewModel.Sheet? = nil,
        availability: VerificationAvailability? = nil
    ) -> ScreenGalleryItem {
        item(id, title) { close in
            CameraVerificationView(
                viewModel: cameraViewModel(state: state, sheet: sheet, availability: availability),
                actions: CameraVerificationView.Actions(close: close, goHome: close, openSubmitted: close)
            )
        }
    }

    private static func cameraViewModel(
        state: CameraVerificationViewModel.State,
        sheet: CameraVerificationViewModel.Sheet?,
        availability: VerificationAvailability?
    ) -> CameraVerificationViewModel {
        let now = Date.now
        let availability = availability ?? .open(deadline: now.addingTimeInterval(MockVerificationRepository.Fixture.remainingUntilDeadline))
        let repository = MockVerificationRepository(delay: mockDelay)
        let (camera, permission) = container().makeCamera()
        return CameraVerificationViewModel(
            fetchSessionUseCase: FetchVerificationSessionUseCase(verificationRepository: repository),
            submitPhotoUseCase: SubmitVerificationPhotoUseCase(verificationRepository: repository),
            camera: camera,
            permission: permission,
            state: state,
            sheet: sheet,
            session: MockVerificationRepository.Fixture.session(availability, serverNow: now)
        )
    }

    /// 가짜 카메라 샘플 이미지로 만든 촬영 사진.
    private static var capturedPhoto: CameraVerificationViewModel.CapturedPhoto {
        let encoded = VerificationPhotoEncoder.encode(FakeCameraService().sampleData)
        let photo = VerificationPhoto(
            id: UUID(),
            jpegData: encoded?.jpegData ?? Data(),
            capturedAt: MockVerificationRepository.Fixture.submittedAt
        )
        return CameraVerificationViewModel.CapturedPhoto(photo: photo, image: encoded?.image ?? UIImage())
    }

    // MARK: - ⑤ 인증 결과

    private static var verificationResult: ScreenGallerySection {
        ScreenGallerySection(title: "인증 결과", items: [
            verificationResultItem("result.processing", "AI 검수 중", scenario: .processing),
            verificationResultItem("result.manualReview", "선생님 확인 중", scenario: .manualReview),
            verificationResultItem("result.approved", "승인", scenario: .approved),
            verificationResultItem("result.rejected", "반려 → 이의신청", scenario: .rejected),
            verificationResultItem("result.processingHistory", "AI 검수 중 · 기록에서 열기", scenario: .processing, entry: .history),
            verificationResultItem("result.approvedHistory", "승인 · 기록에서 열기", scenario: .approved, entry: .history),
            verificationResultItem("result.failure", "조회 실패", scenario: .failure),
            verificationResultItem("result.loading", "불러오는 중", scenario: .approved, delay: loadingDelay)
        ])
    }

    private static func verificationResultItem(
        _ id: String,
        _ title: String,
        scenario: MockVerificationResultRepository.Scenario,
        entry: VerificationResultView.Entry = .submission,
        delay: Duration = mockDelay
    ) -> ScreenGalleryItem {
        item(id, title) { close in
            // 오늘 낸 인증의 결과로 연다. 홈 상태를 결과에 맞춰 두어 이의신청 대상 날짜도 오늘 인증과 같다.
            let container = container(home: homeScenario(for: scenario))
            ScreenGalleryStack { navigator in
                VerificationResultView(
                    viewModel: container.makeVerificationResultViewModel(
                        resultID: container.mockStore.todayVerificationID,
                        repository: MockVerificationResultRepository.matchingOtherMocks(scenario: scenario, delay: delay, store: container.mockStore)
                    ),
                    entry: entry,
                    close: close,
                    goHome: close,
                    appeal: { result in
                        navigator.push(appealForm(
                            target: AppealTarget(result: result),
                            store: container.mockStore,
                            navigator: navigator,
                            back: navigator.pop,
                            close: close
                        ))
                    }
                )
            }
        }
    }

    /// 인증 결과 상태에 맞는 홈(오늘 인증) 상태.
    private static func homeScenario(for scenario: MockVerificationResultRepository.Scenario) -> MockHomeRepository.Scenario {
        switch scenario {
        case .processing: .aiReviewing
        case .manualReview: .teacherReviewing
        case .approved: .approved
        case .rejected: .rejected
        case .failure: .notSubmitted
        }
    }

    // MARK: - ⑥ 이의신청

    private static var appeal: ScreenGallerySection {
        let message = "복도 끝도 청소했는데 사진에서 잘렸어요"
        return ScreenGallerySection(title: "이의신청", items: [
            appealFormItem("appeal.form", "작성 전"),
            appealFormItem("appeal.formPhotos", "작성 중 · 사진 2장 첨부", message: message, photoCount: 2),
            appealFormItem("appeal.formOverLimit", "글자 수 초과", message: String(repeating: "가", count: AppealMessage.maxLength + 1)),
            appealFormItem("appeal.formFailed", "제출 실패", message: message, phase: .failed),
            appealFormItem("appeal.formRetry", "보내기 실패 후 다시 보내기", message: message, submitOutcomes: [.failure, .success]),
            appealFormItem(
                "appeal.formReceivedRetry",
                "보내기 실패(서버는 접수) 후 다시 보내기",
                message: message,
                submitOutcomes: [.failureAfterReceived, .success]
            ),
            item("appeal.submitted", "제출 완료") { close in
                AppealSubmittedView(appeal: seededAppeal(.reviewing), goHome: close)
            },
            item("appeal.submittedFromHistory", "제출 완료 · 내역에서 열기") { close in
                AppealSubmittedView(appeal: seededAppeal(.reviewing), back: close, goHome: close)
            },
            appealHistoryItem("appeal.history", "내역", scenario: .history),
            appealHistoryItem("appeal.historyEmpty", "내역 · 빈 목록", scenario: .empty),
            appealHistoryItem("appeal.historyFailure", "내역 · 조회 실패", scenario: .failure),
            appealHistoryItem("appeal.historyLoading", "내역 · 불러오는 중", scenario: .history, delay: loadingDelay),
            appealResultItem("appeal.result.approved", "결과 · 승인", status: .approved),
            appealResultItem("appeal.result.rejected", "결과 · 반려", status: .rejected),
            appealResultItem("appeal.result.reviewing", "결과 · 검토 중", status: .reviewing)
        ])
    }

    /// 활동 기록에 맞춘 이의신청 내역(`MockStore.appeals`)에서 `status`인 것.
    private static func seededAppeal(_ status: Appeal.Status, store: MockStore = MockStore()) -> Appeal {
        store.appeals.first { $0.status == status } ?? MockAppealRepository.Fixture.reviewing
    }

    private static func appealFormItem(
        _ id: String,
        _ title: String,
        message: String = "",
        photoCount: Int = 0,
        phase: AppealFormViewModel.Phase = .editing,
        submitOutcomes: [MockAppealRepository.SubmitOutcome] = [.success]
    ) -> ScreenGalleryItem {
        item(id, title) { close in
            let store = container().mockStore
            ScreenGalleryStack { navigator in
                appealForm(
                    viewModel: appealFormViewModel(
                        target: store.appealTarget,
                        store: store,
                        message: message,
                        photoCount: photoCount,
                        phase: phase,
                        submitOutcomes: submitOutcomes
                    ),
                    navigator: navigator,
                    back: close,
                    close: close
                )
            }
        }
    }

    private static func appealFormViewModel(
        target: AppealTarget,
        store: MockStore,
        message: String = "",
        photoCount: Int = 0,
        phase: AppealFormViewModel.Phase = .editing,
        submitOutcomes: [MockAppealRepository.SubmitOutcome] = [.success]
    ) -> AppealFormViewModel {
        let viewModel = container().makeAppealFormViewModel(
            target: target,
            repository: MockAppealRepository(submitOutcomes: submitOutcomes, delay: mockDelay, store: store),
            phase: phase
        )
        viewModel.message = message
        let photo = FakeCameraService().sampleData
        for _ in 0..<photoCount {
            viewModel.addPhoto(photo)
        }
        return viewModel
    }

    /// 이의신청 작성. 보내면 완료 화면을 같은 스택에 쌓는다.
    private static func appealForm(
        target: AppealTarget,
        store: MockStore,
        navigator: ScreenGalleryNavigator,
        back: @escaping () -> Void,
        close: @escaping () -> Void
    ) -> some View {
        appealForm(viewModel: appealFormViewModel(target: target, store: store), navigator: navigator, back: back, close: close)
    }

    private static func appealForm(
        viewModel: AppealFormViewModel,
        navigator: ScreenGalleryNavigator,
        back: @escaping () -> Void,
        close: @escaping () -> Void
    ) -> some View {
        AppealFormView(
            viewModel: viewModel,
            back: back,
            makePhotoCapture: { container().makeAppealPhotoCaptureViewModel() },
            onSubmitted: { appeal in
                navigator.push(
                    AppealSubmittedView(appeal: appeal, goHome: close)
                        .toolbar(.hidden, for: .navigationBar)
                        .navigationBarBackButtonHidden()
                )
            }
        )
    }

    private static func appealHistoryItem(
        _ id: String,
        _ title: String,
        scenario: MockAppealRepository.Scenario,
        delay: Duration = mockDelay
    ) -> ScreenGalleryItem {
        item(id, title) { close in
            let container = container()
            ScreenGalleryStack { navigator in
                AppealHistoryView(
                    viewModel: container.makeAppealHistoryViewModel(
                        repository: MockAppealRepository(scenario: scenario, delay: delay, store: container.mockStore)
                    ),
                    back: close,
                    openResult: { appeal in
                        navigator.push(appealResult(appeal, store: container.mockStore, navigator: navigator, back: navigator.pop, close: close))
                    }
                )
            }
        }
    }

    private static func appealResultItem(_ id: String, _ title: String, status: Appeal.Status) -> ScreenGalleryItem {
        item(id, title) { close in
            let store = container().mockStore
            ScreenGalleryStack { navigator in
                appealResult(seededAppeal(status, store: store), store: store, navigator: navigator, back: close, close: close)
            }
        }
    }

    private static func appealResult(
        _ appeal: Appeal,
        store: MockStore,
        navigator: ScreenGalleryNavigator,
        back: @escaping () -> Void,
        close: @escaping () -> Void
    ) -> some View {
        AppealResultView(
            appeal: appeal,
            back: back,
            appealAgain: { target in
                navigator.push(appealForm(target: target, store: store, navigator: navigator, back: navigator.pop, close: close))
            },
            showActivity: close,
            goHome: close
        )
    }

    // MARK: - ⑦ 공지

    private static var notice: ScreenGallerySection {
        ScreenGallerySection(title: "공지", items: [
            noticeItem("notice.list", "목록", scenario: .loaded),
            noticeItem("notice.focused", "목록 · 홈 공지 카드에서 열기", scenario: .loaded, focusedNoticeID: MockHomeRepository.Fixture.notice.id),
            noticeItem("notice.failure", "조회 실패", scenario: .failure),
            noticeItem("notice.loading", "불러오는 중", scenario: .loaded, delay: loadingDelay)
        ])
    }

    private static func noticeItem(
        _ id: String,
        _ title: String,
        scenario: MockNoticeRepository.Scenario,
        focusedNoticeID: Notice.ID? = nil,
        delay: Duration = mockDelay
    ) -> ScreenGalleryItem {
        item(id, title) { close in
            NoticeView(
                viewModel: container().makeNoticeViewModel(repository: MockNoticeRepository(scenario: scenario, delay: delay)),
                focusedNoticeID: focusedNoticeID,
                onBack: close
            )
        }
    }

    // MARK: - ⑧ 마이페이지

    private static var myPage: ScreenGallerySection {
        ScreenGallerySection(title: "마이페이지", items: [
            myPageItem("myPage.guardian", "환경지킴이"),
            myPageItem("myPage.reminderOff", "청소 알림 끔", isCleaningReminderOn: false),
            myPageItem("myPage.notApplied", "미신청", scenario: .notApplied),
            myPageItem("myPage.failure", "조회 실패", scenario: .failure),
            myPageItem("myPage.loading", "불러오는 중", delay: loadingDelay),
            item("myPage.logoutConfirm", "로그아웃 확인") { close in
                let viewModel = myPageViewModel(onLoggedOut: close)
                MyPageView(viewModel: viewModel)
                    .onAppear { viewModel.requestLogout() }
            },
            item("myPage.loggingOut", "로그아웃 중") { close in
                let viewModel = myPageViewModel(logoutDelay: loadingDelay, onLoggedOut: close)
                MyPageView(viewModel: viewModel)
                    .task {
                        viewModel.requestLogout()
                        await viewModel.confirmLogout()
                    }
            }
        ])
    }

    private static func myPageItem(
        _ id: String,
        _ title: String,
        scenario: MockMyPageRepository.Scenario = .guardian,
        delay: Duration = mockDelay,
        isCleaningReminderOn: Bool = true
    ) -> ScreenGalleryItem {
        item(id, title) { close in
            MyPageView(viewModel: myPageViewModel(
                scenario: scenario,
                delay: delay,
                isCleaningReminderOn: isCleaningReminderOn,
                onLoggedOut: close
            ))
        }
    }

    private static func myPageViewModel(
        scenario: MockMyPageRepository.Scenario = .guardian,
        delay: Duration = mockDelay,
        isCleaningReminderOn: Bool = true,
        logoutDelay: Duration = mockDelay,
        onLoggedOut: @escaping () -> Void
    ) -> MyPageViewModel {
        // 앱의 청소 알림 설정을 바꾸지 않게 따로 둔 저장소를 쓴다.
        let defaults = UserDefaults(suiteName: "screenGallery.myPage") ?? .standard
        let settings = NotificationSettingRepositoryImpl(defaults: defaults)
        settings.setCleaningReminderOn(isCleaningReminderOn)
        let container = container(authDelay: logoutDelay)
        return container.makeMyPageViewModel(
            repository: MockMyPageRepository(store: container.mockStore, scenario: scenario, delay: delay),
            notificationSettingRepository: settings,
            onLoggedOut: onLoggedOut
        )
    }

    // MARK: - ⑨ 구역 · 기록

    private static var areaAndRecords: ScreenGallerySection {
        ScreenGallerySection(title: "구역 · 활동 기록", items: [
            areaItem("area.assigned", "구역 · 배정됨", scenario: .assigned),
            areaItem("area.unassigned", "구역 · 미배정", scenario: .unassigned),
            areaItem("area.failure", "구역 · 조회 실패", scenario: .failure),
            areaItem("area.loading", "구역 · 불러오는 중", scenario: .assigned, delay: loadingDelay),
            recordsItem("records.current", "기록 · 이번 달", scenario: .records),
            recordsItem("records.pastMonth", "기록 · 지난 달", scenario: .records, month: previousMonth),
            recordsItem("records.empty", "기록 · 빈 상태", scenario: .empty),
            recordsItem("records.failure", "기록 · 조회 실패", scenario: .failure),
            recordsItem("records.loading", "기록 · 불러오는 중", scenario: .records, delay: loadingDelay)
        ])
    }

    private static func areaItem(
        _ id: String,
        _ title: String,
        scenario: MockCleaningAreaRepository.Scenario,
        delay: Duration = mockDelay
    ) -> ScreenGalleryItem {
        item(id, title) { _ in
            CleaningAreaView(viewModel: container().makeCleaningAreaViewModel(
                repository: MockCleaningAreaRepository(scenario: scenario, delay: delay)
            ))
        }
    }

    private static func recordsItem(
        _ id: String,
        _ title: String,
        scenario: MockActivityRepository.Scenario,
        month: YearMonth? = nil,
        delay: Duration = mockDelay
    ) -> ScreenGalleryItem {
        item(id, title) { close in
            ActivityRecordsView(
                viewModel: recordsViewModel(scenario: scenario, month: month, delay: delay),
                actions: ActivityRecordsView.Actions(verify: close)
            )
        }
    }

    /// 오늘(기기 시계)이 속한 달의 전 달. Mock 기록은 이번 달과 전 달에 있다.
    private static var previousMonth: YearMonth {
        let current = MockStore().currentMonth
        return current.month == 1 ? YearMonth(year: current.year - 1, month: 12) : YearMonth(year: current.year, month: current.month - 1)
    }

    private static func recordsViewModel(
        scenario: MockActivityRepository.Scenario,
        month: YearMonth?,
        delay: Duration
    ) -> ActivityRecordsViewModel {
        let container = container()
        let viewModel = container.makeActivityRecordsViewModel(
            repository: MockActivityRepository(store: container.mockStore, scenario: scenario, delay: delay)
        )
        if let month {
            viewModel.selectMonth(month)
        }
        return viewModel
    }

    // MARK: - ⑩ 공통 컴포넌트

    private static var components: ScreenGallerySection {
        ScreenGallerySection(title: "공통 컴포넌트", items: [
            item("component.toast", "토스트") { _ in
                Color.ecoSurface
                    .ignoresSafeArea()
                    .overlay(alignment: .top) {
                        EcoToast(message: "로그인하지 못했어요. 다시 시도해 주세요")
                            .padding(.top, Spacing.sm)
                            .padding(.horizontal, Spacing.screenHorizontal)
                    }
            },
            item("component.dialog", "확인 팝업") { close in
                Color.ecoCard
                    .ignoresSafeArea()
                    .ecoDialog(isPresented: .constant(true), onCancel: close) {
                        EcoDialog("로그아웃할까요?", message: "다시 들어오려면 DataGSM으로 로그인해야 해요") {
                            EcoButton("취소", style: .secondary, action: close)
                            EcoButton("로그아웃", style: .destructive, action: close)
                        }
                    }
            },
            item("component.monthPicker", "월 선택 팝업") { close in
                ZStack {
                    Color.ecoDim.ignoresSafeArea()
                    EcoMonthPickerDialog(
                        selection: MockActivityRepository.Fixture.month,
                        range: DIContainer.activityRecordsEarliestMonth...MockActivityRepository.Fixture.month,
                        yearTitle: { ActivityRecordsFormatter.year($0) },
                        monthTitle: { ActivityRecordsFormatter.monthOnly($0) },
                        onApply: { _ in close() },
                        onCancel: close
                    )
                    .padding(.horizontal, Spacing.screenHorizontal)
                }
            }
        ])
    }

    // MARK: - 공통

    private static func item(
        _ id: String,
        _ title: String,
        @ViewBuilder content: @escaping (_ close: @escaping () -> Void) -> some View
    ) -> ScreenGalleryItem {
        ScreenGalleryItem(id: id, title: title) { close in AnyView(content(close)) }
    }

    /// 실서버 설정과 상관없이 Mock 저장소만 쓰는 컨테이너. 로그인 저장소가 Mock이라 `apiClient`가 nil이 되어
    /// 화면별 확장(`DIContainer+X`)도 모두 Mock 저장소를 만든다.
    /// 항목마다 `MockStore`를 하나 두어, 그 항목에서 이어지는 화면(탭·결과·이의신청)의 날짜·기록·신청이 서로 맞는다.
    private static func container(
        authOutcome: MockAuthRepository.Outcome = .student,
        authDelay: Duration = mockDelay,
        home: MockHomeRepository.Scenario = .notSubmitted,
        homeDelay: Duration = mockDelay,
        recruitment: MockRecruitmentRepository.Scenario = .open,
        applyOutcomes: [MockRecruitmentRepository.ApplyOutcome] = [.approved],
        recruitmentDelay: Duration = mockDelay
    ) -> DIContainer {
        let store = MockStore(homeScenario: home, recruitmentScenario: recruitment)
        return DIContainer(
            authRepository: MockAuthRepository(outcome: authOutcome, delay: authDelay),
            homeRepository: MockHomeRepository(store: store, delay: homeDelay),
            recruitmentRepository: MockRecruitmentRepository(scenario: recruitment, applyOutcomes: applyOutcomes, delay: recruitmentDelay, store: store),
            webAdminURL: nil,
            mockStore: store
        )
    }
}

/// 화면 모음 안에서 다음 화면을 쌓고 뺀다(인증 결과 → 이의신청 작성 → 완료 등).
struct ScreenGalleryNavigator {
    let pushView: (AnyView) -> Void
    let pop: () -> Void

    func push(_ view: some View) {
        pushView(AnyView(view))
    }
}

/// 항목 화면을 루트로 둔 `NavigationStack`. 루트 화면이 연 다음 화면을 여기에 쌓는다.
struct ScreenGalleryStack<Root: View>: View {
    @ViewBuilder let root: (ScreenGalleryNavigator) -> Root

    @State private var path: [Int] = []
    @State private var pushedViews: [AnyView] = []

    var body: some View {
        NavigationStack(path: $path) {
            root(navigator)
                .navigationDestination(for: Int.self) { index in
                    if pushedViews.indices.contains(index) {
                        pushedViews[index]
                    }
                }
        }
    }

    private var navigator: ScreenGalleryNavigator {
        ScreenGalleryNavigator(
            pushView: { view in
                pushedViews = Array(pushedViews.prefix(path.count)) + [view]
                path.append(pushedViews.count - 1)
            },
            pop: {
                guard !path.isEmpty else { return }
                path.removeLast()
            }
        )
    }
}
#endif
