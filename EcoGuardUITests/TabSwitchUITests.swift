import XCTest

/// 구역·기록 탭을 눌렀을 때 화면이 위로 튀어오르지 않는지(#89). 불러오는 동안의 스켈레톤 제목과 불러온 화면 제목이 같은 자리여야 한다.
/// Mock 저장소는 1초 늦게 응답해 탭을 누른 직후에는 스켈레톤이 보인다.
@MainActor
final class TabSwitchUITests: XCTestCase {
    private let timeout: TimeInterval = 15

    override func setUp() async throws {
        continueAfterFailure = false
    }

    func testAreaTitleStaysInPlaceWhenLoaded() {
        let app = launchLoggedIn()
        assertTitleStaysInPlace(tab: "구역", title: "내 청소 구역", in: app)
    }

    func testRecordsTitleStaysInPlaceWhenLoaded() {
        let app = launchLoggedIn()
        assertTitleStaysInPlace(tab: "기록", title: "활동 기록", in: app)
    }

    /// 탭을 누른 직후(스켈레톤) 제목 위치와 불러온 뒤 제목 위치를 비교한다.
    private func assertTitleStaysInPlace(tab: String, title: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let titleText = app.staticTexts.matching(identifier: title).firstMatch
        let loadingText = app.staticTexts["불러오는 중이에요"]
        app.buttons[tab].tap()
        // `waitForExistence`는 1초 간격으로 확인해 Mock 응답(1초)보다 늦을 수 있다. 탭은 앱이 멈출 때까지 기다린 뒤 돌아온다.
        XCTAssertTrue(titleText.exists, file: file, line: line)
        let loadingTop = titleText.frame.minY
        // 제목을 읽은 뒤에도 스켈레톤이 남아 있어야 스켈레톤 제목을 잰 것이다.
        XCTAssertTrue(loadingText.exists, "\(tab) 탭 스켈레톤이 보이기 전에 불러오기를 마쳤다", file: file, line: line)

        XCTAssertTrue(waitUntil { !loadingText.exists }, "\(tab) 탭을 불러오지 못했다", file: file, line: line)
        XCTAssertEqual(titleText.frame.minY, loadingTop, accuracy: 0.5, "\(tab) 탭 제목이 불러온 뒤 움직였다", file: file, line: line)

        // 0.5초 뒤에도 같은 자리에 있다(늦게 붙는 여백·애니메이션이 없다).
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertEqual(titleText.frame.minY, loadingTop, accuracy: 0.5, "\(tab) 탭 제목이 0.5초 뒤 움직였다", file: file, line: line)
    }

    private func waitUntil(_ condition: @escaping () -> Bool) -> Bool {
        let predicate = NSPredicate { _, _ in condition() }
        return XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: nil)], timeout: timeout) == .completed
    }

    private func launchLoggedIn() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["ECO_USE_MOCK"] = "1"
        app.launch()
        let login = app.buttons["DataGSM으로 로그인"]
        XCTAssertTrue(login.waitForExistence(timeout: timeout))
        login.tap()
        XCTAssertTrue(app.buttons["홈"].waitForExistence(timeout: timeout), "로그인 후 탭 바가 보이지 않는다")
        return app
    }
}
