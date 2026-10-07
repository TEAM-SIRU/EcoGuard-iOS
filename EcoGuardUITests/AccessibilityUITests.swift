import XCTest

/// 접근성 점검(#92). 탭 안에서 push한 화면은 시스템 내비게이션 바를 숨기고 `EcoNavBar`를 쓰지만, 화면 왼쪽 끝에서 밀어 뒤로 갈 수 있어야 한다.
@MainActor
final class AccessibilityUITests: XCTestCase {
    private let timeout: TimeInterval = 15

    override func setUp() async throws {
        continueAfterFailure = false
    }

    func testSwipeBackFromHomeNotices() {
        let app = launchLoggedIn()
        tap(app.buttons["공지"], in: app)
        swipeBack(in: app)
        XCTAssertTrue(app.buttons["전체보기"].waitForExistence(timeout: timeout), "홈으로 돌아오지 않았다")
        XCTAssertFalse(app.buttons["뒤로"].exists, "공지 화면이 남아 있다")
    }

    /// 돌아온 첫 화면에서 다시 밀어도 내비게이션이 멈추지 않고, 다시 push한 화면도 밀어서 돌아간다.
    func testSwipeBackFromMyPageNotices() {
        let app = launchLoggedIn()
        tap(app.buttons["마이페이지"], in: app)
        tap(app.buttons["공지"], in: app)
        swipeBack(in: app)
        XCTAssertTrue(app.buttons["로그아웃"].waitForExistence(timeout: timeout), "마이페이지로 돌아오지 않았다")
        XCTAssertFalse(app.buttons["뒤로"].exists, "공지 화면이 남아 있다")
        // 목록 행 위에서 밀면 행을 누른 것으로 잡혀, 행이 없는 프로필 높이에서 민다.
        edgeSwipe(in: app, atY: 0.15)
        tap(app.buttons["공지"], in: app)
        swipeBack(in: app)
        XCTAssertTrue(app.buttons["로그아웃"].waitForExistence(timeout: timeout), "다시 연 공지에서 돌아오지 않았다")
    }

    func testSwipeBackFromAppealHistory() {
        let app = launchLoggedIn()
        tap(app.buttons["마이페이지"], in: app)
        tap(app.buttons["이의신청 내역"], in: app)
        swipeBack(in: app)
        XCTAssertTrue(app.buttons["로그아웃"].waitForExistence(timeout: timeout), "마이페이지로 돌아오지 않았다")
        XCTAssertFalse(app.buttons["뒤로"].exists, "이의신청 내역 화면이 남아 있다")
    }

    // MARK: - VoiceOver

    /// 홈 공지 카드 머리(제목·날짜·NEW)를 한 요소로 읽는다.
    func testHomeNoticeHeaderIsOneElement() {
        let app = launchLoggedIn()
        let header = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH '환경지킴이 공지, '")).firstMatch
        XCTAssertTrue(header.waitForExistence(timeout: timeout), "공지 카드 머리가 한 요소로 묶이지 않았다")
        XCTAssertEqual(header.value as? String, "새 공지")
        XCTAssertFalse(app.staticTexts["NEW"].exists, "NEW 태그를 따로 읽는다")
    }

    // MARK: - 이의신청 제출 실패

    func testAppealSubmitFailureThenRetry() {
        assertAppealFailureThenRetry(galleryItem: "appeal.formRetry")
    }

    /// 서버는 접수했는데 응답을 못 받은 경우. 다시 보내면 이전 접수를 찾아 완료 화면으로 간다.
    func testAppealSubmitFailureAfterReceivedThenRetry() {
        assertAppealFailureThenRetry(galleryItem: "appeal.formReceivedRetry")
    }

    // MARK: - Helpers

    private func assertAppealFailureThenRetry(galleryItem: String, file: StaticString = #filePath, line: UInt = #line) {
        let app = XCUIApplication()
        app.launchEnvironment["ECO_USE_MOCK"] = "1"
        app.launchArguments = ["-ScreenGallery", galleryItem]
        app.launch()
        tap(app.buttons["이의신청 보내기"], in: app, file: file, line: line)
        XCTAssertTrue(app.staticTexts["이의신청을 보내지 못했어요"].waitForExistence(timeout: timeout), "실패 화면이 뜨지 않았다", file: file, line: line)
        XCTAssertTrue(app.buttons["내용 수정하기"].exists, file: file, line: line)
        saveScreenshot("\(galleryItem)-failed")
        tap(app.buttons["다시 보내기"], in: app, file: file, line: line)
        // 화면 모음 스택은 완료 화면을 빈 화면으로 push해(갤러리 문제) 완료 문구 대신 실패 화면이 닫히고 완료로 넘어갔는지 본다.
        let failedTitle = app.staticTexts["이의신청을 보내지 못했어요"]
        XCTAssertTrue(waitUntil { !failedTitle.exists }, "다시 보내도 실패 화면이 남아 있다", file: file, line: line)
        XCTAssertTrue(app.navigationBars.buttons["BackButton"].waitForExistence(timeout: timeout), "완료 화면을 쌓지 않았다", file: file, line: line)
        XCTAssertFalse(app.staticTexts["이미 접수된 이의신청이 있어요"].exists, "같은 요청을 다른 이의신청으로 판단했다", file: file, line: line)
    }

    private func saveScreenshot(_ name: String) {
        guard let directory = ProcessInfo.processInfo.environment["EG_SHOT_DIR"] else { return }
        let url = URL(fileURLWithPath: directory).appendingPathComponent("\(name).png")
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: url)
    }

    private func launchLoggedIn() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["ECO_USE_MOCK"] = "1"
        app.launch()
        tap(app.buttons["DataGSM으로 로그인"], in: app)
        XCTAssertTrue(app.buttons["홈"].waitForExistence(timeout: timeout), "로그인 후 탭 바가 보이지 않는다")
        return app
    }

    /// push한 화면이 다 열린 뒤 화면 왼쪽 끝에서 오른쪽으로 민다.
    private func swipeBack(in app: XCUIApplication) {
        XCTAssertTrue(app.buttons["뒤로"].waitForExistence(timeout: timeout), "push한 화면이 열리지 않았다")
        XCTAssertTrue(waitUntil { app.buttons["뒤로"].isHittable })
        edgeSwipe(in: app, atY: 0.5)
    }

    private func edgeSwipe(in app: XCUIApplication, atY y: CGFloat) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: y))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: y))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    private func tap(_ element: XCUIElement, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "\(element) 없음", file: file, line: line)
        XCTAssertTrue(waitUntil { element.isHittable }, "\(element) 누를 수 없음", file: file, line: line)
        element.tap()
    }

    private func waitUntil(_ condition: @escaping () -> Bool) -> Bool {
        let predicate = NSPredicate { _, _ in condition() }
        return XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: nil)], timeout: timeout) == .completed
    }
}
