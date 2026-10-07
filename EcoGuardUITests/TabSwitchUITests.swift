import XCTest

/// 로그인 직후 홈, 탭을 누른 직후 구역·기록·마이페이지가 불러오기를 마칠 때 위로 튀어오르지 않는지(#89).
/// 불러오는 동안의 화면과 불러온 화면에서 같은 요소(제목, 첫 메뉴)가 같은 자리여야 한다.
/// Mock 저장소는 1초 늦게 응답해 로그인·탭 직후에는 로딩 화면이 보인다.
@MainActor
final class TabSwitchUITests: XCTestCase {
    private let timeout: TimeInterval = 15

    override func setUp() async throws {
        continueAfterFailure = false
    }

    func testHomeTitleStaysInPlaceAfterLogin() {
        let app = launch()
        app.buttons["DataGSM으로 로그인"].tap()
        // 로그인 응답(1초) 뒤 홈 로딩(1초)이 이어진다. 탭 바가 보이는 즉시 잰다.
        let homeTab = app.buttons["홈"]
        let deadline = Date.now.addingTimeInterval(timeout)
        while !homeTab.exists, Date.now < deadline {}
        assertStaysInPlace(app.staticTexts["환경지킴이"], name: "홈 제목", isLoading: { app.staticTexts["불러오는 중이에요"].exists })
    }

    func testAreaTitleStaysInPlaceWhenLoaded() {
        let app = launchLoggedIn()
        assertTitleStaysInPlace(tab: "구역", title: "내 청소 구역", in: app)
    }

    func testRecordsTitleStaysInPlaceWhenLoaded() {
        let app = launchLoggedIn()
        assertTitleStaysInPlace(tab: "기록", title: "활동 기록", in: app)
    }

    /// 마이페이지는 제목이 없어 프로필 아래 첫 메뉴를 잰다. 프로필 스켈레톤과 불러온 프로필 높이가 다르면 메뉴가 움직인다.
    func testMyPageMenuStaysInPlaceWhenLoaded() {
        let app = launchLoggedIn()
        app.buttons["마이페이지"].tap()
        assertStaysInPlace(app.staticTexts["내 청소 구역"], name: "마이페이지 첫 메뉴", isLoading: { !app.staticTexts["이번 달 승인"].exists })
    }

    /// 탭을 누른 직후(스켈레톤) 제목 위치와 불러온 뒤 제목 위치를 비교한다.
    private func assertTitleStaysInPlace(tab: String, title: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        app.buttons[tab].tap()
        assertStaysInPlace(
            app.staticTexts.matching(identifier: title).firstMatch,
            name: "\(tab) 탭 제목",
            isLoading: { app.staticTexts["불러오는 중이에요"].exists },
            file: file,
            line: line
        )
    }

    /// 로딩 화면에서 잰 요소 위치와 불러온 뒤 위치를 비교한다.
    private func assertStaysInPlace(
        _ element: XCUIElement,
        name: String,
        isLoading: @escaping () -> Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        // `waitForExistence`는 1초 간격으로 확인해 Mock 응답(1초)보다 늦을 수 있다. 탭은 앱이 멈출 때까지 기다린 뒤 돌아온다.
        XCTAssertTrue(element.exists, "\(name)이 보이지 않는다", file: file, line: line)
        let loadingTop = element.frame.minY
        // 위치를 읽은 뒤에도 로딩 중이어야 로딩 화면에서 잰 것이다.
        XCTAssertTrue(isLoading(), "\(name)을 로딩 화면에서 재기 전에 불러오기를 마쳤다", file: file, line: line)

        XCTAssertTrue(waitUntil { !isLoading() }, "\(name) 화면을 불러오지 못했다", file: file, line: line)
        XCTAssertEqual(element.frame.minY, loadingTop, accuracy: 0.5, "\(name)이 불러온 뒤 움직였다", file: file, line: line)

        // 0.5초 뒤에도 같은 자리에 있다(늦게 붙는 여백·애니메이션이 없다).
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertEqual(element.frame.minY, loadingTop, accuracy: 0.5, "\(name)이 0.5초 뒤 움직였다", file: file, line: line)
    }

    private func waitUntil(_ condition: @escaping () -> Bool) -> Bool {
        let predicate = NSPredicate { _, _ in condition() }
        return XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: nil)], timeout: timeout) == .completed
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["ECO_USE_MOCK"] = "1"
        app.launch()
        XCTAssertTrue(app.buttons["DataGSM으로 로그인"].waitForExistence(timeout: timeout))
        return app
    }

    private func launchLoggedIn() -> XCUIApplication {
        let app = launch()
        app.buttons["DataGSM으로 로그인"].tap()
        XCTAssertTrue(app.buttons["홈"].waitForExistence(timeout: timeout), "로그인 후 탭 바가 보이지 않는다")
        return app
    }
}
