import XCTest

final class PickleQuestUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAppLaunches() throws {
        let app = XCUIApplication()
        app.launch()

        // Verify the main tab bar exists
        XCTAssertTrue(app.tabBars.firstMatch.exists)
    }
}
