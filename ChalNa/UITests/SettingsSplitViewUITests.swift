import XCTest

final class SettingsSplitViewUITests: XCTestCase {
    func testOutputResolutionPersistsAndReachesExportInLocalizedSettings() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["CHALNA_APP_MODE"] = "devMock"
        app.launchEnvironment["CHALNA_UI_TEST_ISOLATE_EXPORT_QUOTA"] = "1"

        func launch(language: String) {
            app.launchArguments = ["-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR", "-appLanguage", language]
            app.launch()
        }

        let picker = app.descendants(matching: .any).matching(identifier: "settings.filmOutputResolution").firstMatch
        let languageSettings = app.descendants(matching: .any).matching(identifier: "settings.language").firstMatch

        launch(language: "system")
        tap(app.buttons["home.settings"])
        assertHittable(picker)
        XCTAssertTrue(picker.label.hasPrefix("영상 해상도"))
        tap(picker)
        for option in ["4K", "Full HD", "HD"] { assertHittable(app.buttons[option].firstMatch) }
        let menu = XCTAttachment(screenshot: app.screenshot())
        menu.name = "output-resolution-picker"
        menu.lifetime = .keepAlways
        add(menu)
        tap(app.buttons["4K"].firstMatch)

        app.terminate()
        launch(language: "system")
        tap(app.buttons["home.newFilm"])
        tap(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "협재 바다")).firstMatch)
        tap(app.buttons["picker.confirm"].firstMatch)
        let export = app.buttons["timeline.export"]
        XCTAssertTrue(export.waitForExistence(timeout: 30), app.debugDescription)
        tap(export)
        let format = app.staticTexts["export.outputFormat"]
        XCTAssertTrue(format.waitForExistence(timeout: 10))
        XCTAssertEqual(format.label, "2160 × 3840 · 30fps")

        app.terminate()
        launch(language: "en")
        tap(app.buttons["home.settings"])
        assertHittable(picker)
        assertResolution(picker, label: "Video Resolution", selection: "4K")
        tap(picker)
        tap(app.buttons["HD"].firstMatch)
        tap(languageSettings)
        assertHittable(app.buttons["System"].firstMatch)

        app.terminate()
        launch(language: "ja")
        tap(app.buttons["home.settings"])
        assertHittable(picker)
        assertResolution(picker, label: "動画の解像度", selection: "HD")
        tap(picker)
        tap(app.buttons["Full HD"].firstMatch)
        assertResolution(picker, label: "動画の解像度", selection: "Full HD")
        tap(languageSettings)
        assertHittable(app.buttons["システム設定"].firstMatch)
    }

    func testVideoStorageSelectionPersistsAfterRelaunch() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR", "-appLanguage", "system"]
        app.launch()

        let settings = app.buttons["home.settings"]
        let storage = app.descendants(matching: .any).matching(identifier: "settings.filmStorage").firstMatch
        let photosOnly = app.buttons["settings.filmStorage.photosOnly"].firstMatch
        let appAndPhotos = app.buttons["settings.filmStorage.appAndPhotos"].firstMatch
        tap(settings)
        tap(storage)
        assertHittable(photosOnly)
        assertHittable(appAndPhotos)
        XCTAssertNotEqual(photosOnly.isSelected, appAndPhotos.isSelected)
        let initial = photosOnly.isSelected ? photosOnly : appAndPhotos
        let alternate = photosOnly.isSelected ? appAndPhotos : photosOnly
        let initialScreenshot = XCTAttachment(screenshot: app.screenshot())
        initialScreenshot.name = "film-storage-initial-selection"
        initialScreenshot.lifetime = .keepAlways
        add(initialScreenshot)

        tap(alternate)
        XCTAssertTrue(alternate.isSelected)
        app.terminate()
        app.launchArguments = ["-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR", "-appLanguage", "en"]
        app.launch()
        tap(settings)
        tap(storage)
        assertHittable(alternate)
        XCTAssertTrue(alternate.isSelected)
        XCTAssertFalse(initial.isSelected)
        XCTAssertEqual(photosOnly.label, "Save to Photos Only")
        XCTAssertEqual(appAndPhotos.label, "Save to This App and Photos")
        let savedScreenshot = XCTAttachment(screenshot: app.screenshot())
        savedScreenshot.name = "film-storage-saved-selection"
        savedScreenshot.lifetime = .keepAlways
        add(savedScreenshot)
        tap(initial)
    }

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

    private func assertResolution(_ picker: XCUIElement, label: String, selection: String,
                                  file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(picker.label.hasPrefix(label), picker.debugDescription, file: file, line: line)
        let combinedSelection = String(picker.label.dropFirst(label.count))
            .trimmingCharacters(in: .punctuationCharacters.union(.whitespaces))
        XCTAssertTrue(picker.value as? String == selection || combinedSelection == selection,
                      picker.debugDescription, file: file, line: line)
    }

    private func assertHittable(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let ready = NSPredicate { _, _ in element.exists && element.isHittable }
        let expectation = XCTNSPredicateExpectation(predicate: ready, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 8), .completed,
                       element.debugDescription, file: file, line: line)
    }
}
