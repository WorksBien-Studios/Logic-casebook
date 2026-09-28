import XCTest

@MainActor
final class LogicCasebookUITests: XCTestCase {
    private func launchedApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["UITEST_SKIP_TUTORIAL"]
        app.launch()
        return app
    }

    func testLibraryListAppearsOnLaunch() throws {
        let app = launchedApp()
        XCTAssertTrue(app.collectionViews["casebook.library.list"].waitForExistence(timeout: 15)
            || app.tables["casebook.library.list"].waitForExistence(timeout: 5))
    }

    func testHelpTabReopensTheTutorial() throws {
        let app = launchedApp()
        XCTAssertTrue(app.tabBars.buttons["ヘルプ"].waitForExistence(timeout: 15))
        app.tabBars.buttons["ヘルプ"].tap()

        let replayButton = app.buttons["チュートリアルをもう一度見る"]
        XCTAssertTrue(replayButton.waitForExistence(timeout: 5))
        replayButton.tap()

        XCTAssertTrue(app.buttons["次へ"].waitForExistence(timeout: 5))
        app.buttons["閉じる"].tap()
    }

    func testBeginnerSectionIsVisibleFromFirstLaunch() throws {
        // Spec §4.2: all four difficulties are visible from first launch,
        // with no requirement to clear easier ones first.
        let app = launchedApp()
        XCTAssertTrue(app.staticTexts["初級"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["中級"].exists)
        XCTAssertTrue(app.staticTexts["上級"].exists)
        XCTAssertTrue(app.staticTexts["エキスパート"].exists)
    }
}
