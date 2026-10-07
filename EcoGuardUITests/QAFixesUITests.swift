import XCTest

/// QA 스윕에서 나온 화면 결함(#81). Mock 저장소로 실행하고, 화면 하나만 볼 때는 `-ScreenGallery <항목 ID>`로 바로 연다.
/// `TEST_RUNNER_EG_SHOT_DIR`을 주면 확인한 화면을 그 폴더에 PNG로 남긴다.
@MainActor
final class QAFixesUITests: XCTestCase {
    private let timeout: TimeInterval = 15

    override func setUp() async throws {
        continueAfterFailure = false
    }

    /// 신청 기간이 지금을 포함하는 공고는 `신청하기`가 켜져 있다. 신청 기간은 `ECO_MOCK_RECRUITMENT_PERIOD`로 지금 기준으로 옮긴다.
    func testOpenRecruitmentEnablesApply() {
        let app = XCUIApplication()
        app.launchEnvironment["ECO_USE_MOCK"] = "1"
        app.launchEnvironment["ECO_MOCK_HOME_SCENARIO"] = "recruiting"
        app.launchEnvironment["ECO_MOCK_RECRUITMENT_SCENARIO"] = "open"
        app.launchEnvironment["ECO_MOCK_RECRUITMENT_PERIOD"] = "current"
        app.launch()
        tap(app.buttons["DataGSM으로 로그인"])
        tap(app.buttons["모집 공고 보기"])

        let apply = app.buttons["신청하기"]
        XCTAssertTrue(apply.waitForExistence(timeout: timeout))
        let isEnabled = waitUntil { apply.isEnabled }
        saveScreenshot("notice-open")
        XCTAssertTrue(isEnabled, "신청 기간인데 `신청하기`가 꺼져 있다")
        tap(apply)
        XCTAssertTrue(app.staticTexts["환경지킴이 신청"].waitForExistence(timeout: timeout), "신청서가 열리지 않았다")
    }

    /// 도움말은 디자인 대기라 화면을 옮기지 않고 준비 중 토스트를 띄운다.
    func testHelpShowsPreparingToast() {
        let app = XCUIApplication()
        app.launchEnvironment["ECO_USE_MOCK"] = "1"
        app.launch()
        tap(app.buttons["DataGSM으로 로그인"])
        tap(app.buttons["마이페이지"])
        tap(app.buttons["도움말"])

        XCTAssertTrue(app.staticTexts["도움말은 준비 중이에요"].waitForExistence(timeout: timeout), "준비 중 토스트가 뜨지 않았다")
        XCTAssertTrue(app.buttons["마이페이지"].isSelected)
        saveScreenshot("help-toast")
    }

    /// 조회 실패 화면의 제목·월 선택이 기록 화면과 같은 자리에 있다.
    func testRecordsFailureHeaderMatchesLoaded() {
        let loaded = titleAndMonthY(galleryItem: "records.current", readyText: "이번 달 활동 시간")
        let failed = titleAndMonthY(galleryItem: "records.failure", readyText: "기록을 불러오지 못했어요")

        XCTAssertEqual(failed.title, loaded.title, accuracy: 0.5, "제목 y가 다르다")
        XCTAssertEqual(failed.month, loaded.month, accuracy: 0.5, "월 선택 y가 다르다")
    }

    /// 지난 달 빈 기록은 인증하라고 권하지 않는다.
    func testPastEmptyMonthHasNoVerifyButton() {
        let app = launchGallery("records.empty")
        XCTAssertTrue(app.staticTexts["이번 달 기록이 아직 없어요"].waitForExistence(timeout: timeout))
        XCTAssertTrue(app.buttons["청소 인증하러 가기"].exists, "이번 달 빈 상태에는 인증 버튼이 있다")

        tap(app.buttons.matching(NSPredicate(format: "label ENDSWITH '월'")).firstMatch)
        tap(app.buttons.matching(NSPredicate(format: "label == '3월'")).firstMatch)
        tap(app.buttons["적용"])

        XCTAssertTrue(app.staticTexts["3월 기록이 아직 없어요"].waitForExistence(timeout: timeout))
        XCTAssertTrue(app.staticTexts["이 달에는 인증 기록이 없어요"].exists)
        XCTAssertFalse(app.buttons["청소 인증하러 가기"].exists, "지난 달 빈 상태에 인증 버튼이 남아 있다")
        saveScreenshot("records-past-empty")
    }

    /// 키보드가 올라와도 신청 동기 입력란 아래(글자 수)가 하단 신청 버튼 위에 보인다.
    func testApplyCounterStaysAboveSubmitWhileTyping() {
        let app = launchGallery("recruitment.apply")
        let field = app.textFields["신청 동기"].exists ? app.textFields["신청 동기"] : app.textViews["신청 동기"]
        tap(field)
        field.typeText("환경을 지키고 싶어요")

        let counter = app.staticTexts["200자 중 11자"]
        let submit = app.buttons["신청하기"]
        XCTAssertTrue(counter.waitForExistence(timeout: timeout))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: timeout), "키보드가 올라오지 않았다")
        // 키보드·스크롤 애니메이션이 끝난 뒤의 자리를 본다.
        XCTAssertTrue(waitUntil { counter.frame.maxY <= submit.frame.minY }, "글자 수(\(counter.frame))가 신청 버튼(\(submit.frame))에 가려졌다")
        saveScreenshot("apply-keyboard")
    }

    // MARK: - Helpers

    private func launchGallery(_ itemID: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["ECO_USE_MOCK"] = "1"
        app.launchArguments = ["-ScreenGallery", itemID]
        app.launch()
        return app
    }

    private func titleAndMonthY(galleryItem: String, readyText: String) -> (title: CGFloat, month: CGFloat) {
        let app = launchGallery(galleryItem)
        XCTAssertTrue(app.staticTexts[readyText].waitForExistence(timeout: timeout), "\(galleryItem) 화면이 열리지 않았다")
        let title = app.staticTexts["활동 기록"].frame.minY
        let month = app.buttons.matching(NSPredicate(format: "label ENDSWITH '월'")).firstMatch.frame.minY
        saveScreenshot(galleryItem)
        app.terminate()
        return (title, month)
    }

    private func saveScreenshot(_ name: String) {
        guard let directory = ProcessInfo.processInfo.environment["EG_SHOT_DIR"] else { return }
        let url = URL(fileURLWithPath: directory).appendingPathComponent("\(name).png")
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: url)
    }

    private func tap(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "\(element) 없음", file: file, line: line)
        XCTAssertTrue(waitUntil { element.isHittable }, "\(element) 누를 수 없음", file: file, line: line)
        element.tap()
    }

    private func waitUntil(_ condition: @escaping () -> Bool) -> Bool {
        let predicate = NSPredicate { _, _ in condition() }
        return XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: nil)], timeout: timeout) == .completed
    }
}
