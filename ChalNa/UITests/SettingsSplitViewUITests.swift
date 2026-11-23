import XCTest

final class SettingsSplitViewUITests: XCTestCase {
    func testSettingsNavigationPreservesTheUnsentSupportDraft() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["CHALNA_APP_MODE"] = "devMock"
        app.launchArguments += ["-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        app.launch()

        tap(app.buttons["home.settings"])
        let language = app.descendants(matching: .any).matching(identifier: "settings.language").firstMatch
        let support = app.descendants(matching: .any).matching(identifier: "settings.support").firstMatch
        let close = app.buttons["settings.close"].firstMatch
        let english = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "English")).firstMatch
        let editor = app.textViews.firstMatch

        tap(language)
        assertHittable(english)
        let window = app.windows.firstMatch.frame
        // 펼친 Duo는 양방향 모두 짧은 변이 669pt다. 닫힌 Duo와 일반 iPhone은 한 열이다.
        let expectsTwoColumns = min(window.width, window.height) >= 600
        if expectsTwoColumns {
            assertHittable(support)
            XCTAssertLessThan(support.frame.midX, english.frame.minX, app.debugDescription)
        } else {
            XCTAssertFalse(support.exists && support.isHittable)
            goBackToMenu(in: app)
        }
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = expectsTwoColumns ? "settings-language-two-columns" : "settings-compact-menu"
        shot.lifetime = .keepAlways
        add(shot)

        tap(support)
        tap(editor)
        let draft = "Keep this draft"
        editor.typeText(draft)
        XCTAssertEqual(editor.value as? String, draft)
        if !expectsTwoColumns { goBackToMenu(in: app) }
        tap(language)
        assertHittable(english)
        if !expectsTwoColumns { goBackToMenu(in: app) }
        tap(support)
        assertHittable(editor)
        XCTAssertEqual(editor.value as? String, draft)

        if !expectsTwoColumns { goBackToMenu(in: app) }
        tap(close)
        assertHittable(app.buttons["home.newFilm"])
    }

    private func goBackToMenu(in app: XCUIApplication) {
        let nativeBack = app.buttons.matching(NSPredicate(
            format: "identifier == %@ OR (identifier != %@ AND label IN %@)",
            "BackButton", "home.settings", ["설정", "Settings", "뒤로", "Back"]
        )).firstMatch
        tap(nativeBack)
    }

    private func tap(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        assertHittable(element, file: file, line: line)
        element.tap()
    }

    private func assertHittable(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let ready = NSPredicate { _, _ in element.exists && element.isHittable }
        let expectation = XCTNSPredicateExpectation(predicate: ready, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 8), .completed,
                       element.debugDescription, file: file, line: line)
    }
}
