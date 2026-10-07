import XCTest

/// 모든 `홈으로`가 띄운 흐름을 닫고 홈 탭 첫 화면으로 돌아가는지(#77). Mock 저장소로 실행하고, 환경 변수로 Mock 상태를 고른다.
@MainActor
final class GoHomeUITests: XCTestCase {
    private let timeout: TimeInterval = 15

    override func setUp() async throws {
        continueAfterFailure = false
    }

    // MARK: - 청소 인증

    func testCameraSubmittedGoHomeFromAreaTab() {
        let app = launchLoggedIn()
        selectTab("구역", in: app)
        submitVerificationPhoto(in: app)
        tapGoHome(in: app)
        assertHomeRoot(in: app)
    }

    func testCameraSubmittedGoHomeClosesHomeNotices() {
        let app = launchLoggedIn()
        tap(app.buttons["공지"], in: app)
        XCTAssertTrue(app.buttons["뒤로"].waitForExistence(timeout: timeout), "공지 화면이 열리지 않았다")
        submitVerificationPhoto(in: app)
        tapGoHome(in: app)
        assertHomeRoot(in: app)
    }

    func testCameraLoadFailedGoHomeFromRecordsTab() {
        let app = launchLoggedIn(["ECO_MOCK_VERIFICATION_SCENARIO": "failure"])
        selectTab("기록", in: app)
        tap(app.buttons["청소 인증하기"], in: app)
        XCTAssertTrue(app.staticTexts["인증 정보를 불러오지 못했어요"].waitForExistence(timeout: timeout))
        tapGoHome(in: app)
        assertHomeRoot(in: app)
    }

    // MARK: - 인증 결과·이의신청

    func testVerificationResultGoHomeFromRecordsTab() {
        let app = launchLoggedIn(["ECO_MOCK_VERIFICATION_RESULT_SCENARIO": "failure"])
        selectTab("기록", in: app)
        let record = app.buttons.matching(NSPredicate(format: "label CONTAINS '일'")).matching(NSPredicate(format: "label CONTAINS '승인' OR label CONTAINS '반려' OR label CONTAINS '검토'")).firstMatch
        tap(record, in: app)
        XCTAssertTrue(app.staticTexts["결과를 불러오지 못했어요"].waitForExistence(timeout: timeout))
        tapGoHome(in: app)
        assertHomeRoot(in: app)
    }

    func testAppealResultsGoHomeFromMyPage() {
        // 반려(317:1177)·승인(514:194) 결과. 검토 중 내역은 결과를 열지 않는다.
        for status in ["반려", "승인"] {
            let app = launchLoggedIn()
            openAppealResult(status, in: app)
            tapGoHome(in: app)
            assertHomeRoot(in: app, context: status)
            app.terminate()
        }
    }

    /// 이의신청 결과 흐름 안에서 작성 → 보내기로 쌓인 완료 화면(317:980)의 `홈으로`.
    func testAppealSubmittedGoHomeFromMyPage() {
        let app = launchLoggedIn()
        openAppealResult("반려", in: app)
        tap(app.buttons["다시 이의신청하기"], in: app)
        XCTAssertTrue(app.buttons["이의신청 보내기"].waitForExistence(timeout: timeout))
        // 여러 줄 `TextField`는 text view나 text field로 잡힌다.
        let message = app.textViews["내용"].exists ? app.textViews["내용"] : app.textFields["내용"]
        tap(message, in: app)
        message.typeText("복도 끝도 청소했는데 사진에서 잘렸어요")
        tap(app.buttons["이의신청 보내기"], in: app)
        tapGoHome(in: app)
        assertHomeRoot(in: app)
    }

    // MARK: - 모집

    func testApplicationResultGoHomeFromMyPage() {
        let app = launchLoggedIn()
        selectTab("마이페이지", in: app)
        tap(app.buttons.matching(NSPredicate(format: "label BEGINSWITH '신청 결과'")).firstMatch, in: app)
        tapGoHome(in: app)
        assertHomeRoot(in: app)
    }

    func testRecruitmentGoHome() {
        let app = launchLoggedIn([
            "ECO_MOCK_HOME_SCENARIO": "recruiting",
            "ECO_MOCK_RECRUITMENT_SCENARIO": "failure"
        ])
        tap(app.buttons["모집 공고 보기"], in: app)
        XCTAssertTrue(app.staticTexts["모집 공고를 불러오지 못했어요"].waitForExistence(timeout: timeout))
        tapGoHome(in: app)
        XCTAssertTrue(app.buttons["모집 공고 보기"].waitForExistence(timeout: timeout), "모집 흐름이 닫히지 않았다")
        XCTAssertTrue(app.buttons["홈"].isSelected)
    }

    // MARK: - 활동 제외

    /// 이미 홈 첫 화면이라 옮길 곳이 없다. 화면을 둔 채 다시 확인하고, 그대로면 토스트로 알린다.
    func testExcludedGoHomeRechecksAndShowsFeedback() {
        let app = launchLoggedIn(["ECO_MOCK_HOME_SCENARIO": "excluded"])
        XCTAssertTrue(app.staticTexts["환경지킴이 활동이 취소됐어요"].waitForExistence(timeout: timeout))
        tapGoHome(in: app)
        XCTAssertTrue(app.staticTexts["아직 활동에서 제외된 상태예요"].waitForExistence(timeout: timeout), "다시 확인한 결과를 알리지 않았다")
        XCTAssertTrue(app.staticTexts["환경지킴이 활동이 취소됐어요"].exists)
        XCTAssertTrue(app.buttons["홈"].isSelected)
    }

    // MARK: - Helpers

    private func launchLoggedIn(_ environment: [String: String] = [:]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["ECO_USE_MOCK"] = "1"
        app.launchEnvironment.merge(environment) { _, new in new }
        app.launch()
        tap(app.buttons["DataGSM으로 로그인"], in: app)
        XCTAssertTrue(app.buttons["홈"].waitForExistence(timeout: timeout), "로그인 후 탭 바가 보이지 않는다")
        return app
    }

    private func selectTab(_ title: String, in app: XCUIApplication) {
        tap(app.buttons[title], in: app)
        XCTAssertTrue(app.buttons[title].isSelected)
    }

    /// 촬영 안내 → 촬영 → 보내기 → 제출 완료. 시뮬레이터는 가짜 카메라(샘플 이미지)를 쓴다.
    private func submitVerificationPhoto(in app: XCUIApplication) {
        // 홈 카드에도 같은 이름의 버튼이 있어 탭 바 카메라 버튼(마지막)을 누른다.
        tap(app.buttons.matching(identifier: "청소 인증하기").allElementsBoundByIndex.last ?? app.buttons["청소 인증하기"], in: app)
        tap(app.buttons["촬영하기"], in: app)
        tap(app.buttons["촬영"], in: app)
        tap(app.buttons["보내기"], in: app)
        XCTAssertTrue(app.staticTexts["사진을 보냈어요"].waitForExistence(timeout: timeout))
    }

    private func openAppealResult(_ status: String, in app: XCUIApplication) {
        selectTab("마이페이지", in: app)
        tap(app.buttons["이의신청 내역"], in: app)
        tap(app.buttons.matching(NSPredicate(format: "label ENDSWITH %@", status)).firstMatch, in: app)
    }

    private func tapGoHome(in app: XCUIApplication) {
        tap(app.buttons["홈으로"], in: app)
    }

    /// 흐름이 닫히고 홈 탭이 선택됐으며, 홈에 쌓인 화면(공지) 없이 홈 첫 화면이 보인다.
    private func assertHomeRoot(in app: XCUIApplication, context: String = "", file: StaticString = #filePath, line: UInt = #line) {
        let homeTab = app.buttons["홈"]
        XCTAssertTrue(homeTab.waitForExistence(timeout: timeout), "탭 바가 보이지 않는다(흐름이 닫히지 않음) \(context)", file: file, line: line)
        XCTAssertTrue(waitUntil { homeTab.isSelected }, "홈 탭이 선택되지 않았다 \(context)", file: file, line: line)
        XCTAssertFalse(app.buttons["홈으로"].exists, "`홈으로` 화면이 남아 있다 \(context)", file: file, line: line)
        XCTAssertFalse(app.buttons["뒤로"].exists, "홈 첫 화면이 아니다(공지 등이 쌓여 있음) \(context)", file: file, line: line)
        XCTAssertTrue(app.buttons["공지"].waitForExistence(timeout: timeout), "홈 화면이 보이지 않는다 \(context)", file: file, line: line)
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
