import XCTest

/// 심사용 데모 계정 진입(#101). 로그인 화면 로고·앱 이름을 길게 누르면 코드 입력 창이 뜨고, 입력한 코드로 로그인한다.
/// Mock 모드라 코드 내용과 상관없이 학생으로 로그인된다.
@MainActor
final class ReviewLoginUITests: XCTestCase {
    private let timeout: TimeInterval = 15

    override func setUp() async throws {
        continueAfterFailure = false
    }

    func testLongPressOpensReviewLoginAndLogsIn() {
        let app = launch()
        let alert = app.alerts["심사용 로그인"]

        // 짧게 누르면 열리지 않는다.
        app.staticTexts["환경지킴이"].press(forDuration: 0.5)
        XCTAssertFalse(alert.waitForExistence(timeout: 1), "짧게 눌렀는데 심사용 로그인이 열렸다")

        app.staticTexts["환경지킴이"].press(forDuration: 2.5)
        XCTAssertTrue(alert.waitForExistence(timeout: timeout), "길게 눌러도 심사용 로그인이 열리지 않았다")

        let submit = alert.buttons["로그인"]
        XCTAssertFalse(submit.isEnabled, "코드가 비어 있는데 로그인 버튼이 눌린다")

        let codeField = alert.secureTextFields.firstMatch
        codeField.tap()
        codeField.typeText("review-code")
        XCTAssertTrue(submit.isEnabled, "코드를 입력했는데 로그인 버튼이 눌리지 않는다")
        submit.tap()

        XCTAssertTrue(app.buttons["홈"].waitForExistence(timeout: timeout), "심사용 로그인 후 탭 바가 보이지 않는다")
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["ECO_USE_MOCK"] = "1"
        app.launch()
        XCTAssertTrue(app.buttons["DataGSM으로 로그인"].waitForExistence(timeout: timeout))
        return app
    }
}
