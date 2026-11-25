import XCTest

/// 작은 화면의 편집 도구 접근성과 회전 전후의 편집 상태를 검사한다.
final class TimelineLayoutUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testTimelineFitsOnScreen_EditToolbarVisible() throws {
        let app = openTimeline()

        assertControlsVisible(in: app)
        XCTAssertTrue(app.collectionViews.firstMatch.exists)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "timeline-layout"
        attachment.lifetime = .keepAlways
        add(attachment)

        app.buttons["timeline.export"].tap()
        XCTAssertTrue(app.staticTexts["출력 형식"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["필름 만들기"].isEnabled)
    }

    func testRotationPreservesSelectedClipOrderAndPlayhead() throws {
        let device = XCUIDevice.shared
        device.orientation = .portrait
        defer { device.orientation = .portrait }
        let app = openTimeline()
        let collection = app.collectionViews.firstMatch
        let first = collection.descendants(matching: .any).matching(identifier: "timeline.clip.0").firstMatch
        let second = collection.descendants(matching: .any).matching(identifier: "timeline.clip.1").firstMatch
        XCTAssertTrue(second.waitForExistence(timeout: 10))
        second.tap()
        XCTAssertTrue(second.isSelected)
        let firstLabel = first.label
        let secondLabel = second.label
        let time = app.staticTexts["timeline.playhead"].label
        XCTAssertNotEqual(time, "00:00.0")

        let window = app.windows.firstMatch
        let startedWide = window.frame.width > window.frame.height
        device.orientation = .landscapeLeft
        let rotated = NSPredicate { _, _ in
            let frame = app.windows.firstMatch.frame
            return (frame.width > frame.height) != startedWide
        }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: rotated, object: nil)], timeout: 8), .completed)
        XCTAssertTrue(second.isSelected)
        XCTAssertEqual(first.label, firstLabel)
        XCTAssertEqual(second.label, secondLabel)
        XCTAssertEqual(app.staticTexts["timeline.playhead"].label, time)
        assertControlsVisible(in: app)

    }

    func testDeleteAlertCancelsAndRemovesOnlyTheSelectedClip() throws {
        let app = openTimeline()
        let clips = app.collectionViews.firstMatch.descendants(matching: .any)
        let first = clips.matching(identifier: "timeline.clip.0").firstMatch
        let second = clips.matching(identifier: "timeline.clip.1").firstMatch
        XCTAssertTrue(second.waitForExistence(timeout: 10))
        second.tap()
        let selectedLabel = second.label
        let time = app.staticTexts["timeline.playhead"].label
        let delete = app.buttons["timeline.delete"]

        delete.tap()
        let alert = app.alerts["클립을 삭제할까요?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        let window = app.windows.firstMatch.frame
        XCTAssertTrue(alert.frame.contains(CGPoint(x: window.midX, y: window.midY)))
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "timeline-delete-alert"
        attachment.lifetime = .keepAlways
        add(attachment)
        alert.buttons["취소"].tap()
        XCTAssertTrue(first.exists && second.isSelected)
        XCTAssertEqual(second.label, selectedLabel)
        XCTAssertEqual(app.staticTexts["timeline.playhead"].label, time)

        delete.tap()
        alert.buttons["삭제"].tap()
        XCTAssertTrue(second.waitForNonExistence(timeout: 5))
        XCTAssertTrue(first.isSelected)
        XCTAssertEqual(app.staticTexts["timeline.playhead"].label, "00:00.0")
        assertControlsVisible(in: app)

        delete.tap()
        alert.buttons["삭제"].tap()
        XCTAssertTrue(first.waitForNonExistence(timeout: 5))
        for id in ["timeline.adjust", "timeline.caption", "timeline.delete", "timeline.export"] {
            XCTAssertFalse(app.buttons[id].isEnabled)
        }
    }

    func testTrimVideoFromBothEndsAndCancelSubsequentChanges() {
        XCUIDevice.shared.orientation = .portrait
        let app = openTimeline()
        let trim = app.buttons["timeline.trim"]
        XCTAssertFalse(trim.exists, "Live Photo에는 자르기를 표시하지 않는다")
        let video = app.collectionViews.firstMatch.descendants(matching: .any)
            .matching(identifier: "timeline.clip.1").firstMatch
        video.tap()
        let untrimmedLabel = video.label
        trim.tap()

        let elements = app.descendants(matching: .any)
        let start = elements.matching(identifier: "trim.start").firstMatch
        let end = elements.matching(identifier: "trim.end").firstMatch
        let done = app.buttons["trim.done"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        let ready = NSPredicate(format: "enabled == true")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: ready, object: done)], timeout: 10), .completed)
        let initialStart = start.value as? String
        let initialEnd = end.value as? String
        let distance = (end.frame.midX - start.frame.midX) * 0.24
        func drag(_ handle: XCUIElement, by dx: CGFloat) {
            let point = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            point.press(forDuration: 0.15, thenDragTo: point.withOffset(CGVector(dx: dx, dy: 0)))
        }
        drag(start, by: distance)
        drag(end, by: -distance)
        let changedStart = start.value as? String
        let changedEnd = end.value as? String
        XCTAssertNotEqual(changedStart, initialStart)
        XCTAssertNotEqual(changedEnd, initialEnd)
        app.buttons["trim.play"].tap()
        done.tap()
        XCTAssertTrue(trim.waitForExistence(timeout: 10))
        XCTAssertNotEqual(video.label, untrimmedLabel)
        let editedLabel = video.label

        trim.tap()
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        XCTAssertEqual(start.value as? String, changedStart)
        XCTAssertEqual(end.value as? String, changedEnd)
        drag(start, by: -distance)
        XCTAssertNotEqual(start.value as? String, changedStart)
        app.buttons["trim.cancel"].tap()
        XCTAssertTrue(trim.waitForExistence(timeout: 5))
        XCTAssertEqual(video.label, editedLabel)
        trim.tap()
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        XCTAssertEqual(start.value as? String, changedStart)
        XCTAssertEqual(end.value as? String, changedEnd)

        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        let landscape = NSPredicate { _, _ in app.windows.firstMatch.frame.width > app.windows.firstMatch.frame.height }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: landscape, object: nil)], timeout: 8), .completed)
        for control in [start, end, done, app.buttons["trim.cancel"]] {
            XCTAssertTrue(control.isHittable)
            XCTAssertTrue(app.windows.firstMatch.frame.contains(control.frame))
        }
    }

    private func openTimeline() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["CHALNA_APP_MODE"] = "devMock"
        app.launchArguments += ["-AppleLanguages", "(ko)"]
        app.launch()

        let newVlog = app.buttons["home.newFilm"].firstMatch
        XCTAssertTrue(newVlog.waitForExistence(timeout: 10), "홈의 새 필름 버튼")
        newVlog.tap()

        // dev fixture 2개 선택
        let firstAsset = app.buttons.matching(NSPredicate(format: "label CONTAINS '협재 바다'")).firstMatch
        XCTAssertTrue(firstAsset.waitForExistence(timeout: 10), "dev fixture: 협재 바다")
        firstAsset.tap()
        let secondAsset = app.buttons.matching(NSPredicate(format: "label CONTAINS '카페 테이블'")).firstMatch
        XCTAssertTrue(secondAsset.waitForExistence(timeout: 5), "dev fixture: 카페 테이블")
        secondAsset.tap()

        let confirm = app.buttons["picker.confirm"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "편집으로 이동하는 버튼")
        confirm.tap()
        XCTAssertTrue(app.buttons["timeline.adjust"].waitForExistence(timeout: 45), app.debugDescription)
        return app
    }

    private func assertControlsVisible(in app: XCUIApplication) {
        let exportInNavigation = app.navigationBars.buttons["timeline.export"].firstMatch
        let exportInToolbar = app.toolbars.buttons["timeline.export"].firstMatch
        let nativeItemReady = NSPredicate { _, _ in
            (exportInNavigation.exists && exportInNavigation.isHittable) ||
            (exportInToolbar.exists && exportInToolbar.isHittable)
        }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: nativeItemReady, object: nil)], timeout: 10),
                       .completed, "시스템 탐색 막대에서 필름 만들기 버튼을 누를 수 있어야 한다")
        // 선택한 장면의 세 편집 도구와 상단 출력 버튼이 모두 화면 안에 있어야 한다.
        let screen = app.windows.firstMatch.frame
        if ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] == "iPhone19,4",
           screen.width > screen.height {
            let export = app.buttons["timeline.export"].firstMatch
            XCTAssertGreaterThan(export.frame.minX, screen.maxX - 110)
            XCTAssertGreaterThan(export.frame.midY, screen.minY + 60)
            let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            attachment.name = "duo-navigation-and-edit-tools"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        for label in ["timeline.adjust", "timeline.caption", "timeline.delete", "timeline.export"] {
            let button = app.buttons[label].firstMatch
            XCTAssertTrue(button.isEnabled)
            XCTAssertTrue(button.waitForExistence(timeout: 15), "타임라인 '\(label)' 버튼이 없다")
            XCTAssertTrue(button.isHittable, "'\(label)' 버튼이 탭 불가 — 화면 밖으로 밀렸을 가능성")
            XCTAssertTrue(
                screen.contains(button.frame),
                "'\(label)' 버튼이 화면(\(screen)) 밖에 있다: \(button.frame) — 세로 예산 초과"
            )
        }

        // 재생 컨트롤도 화면 안에 있어야 한다.
        let playToggle = app.buttons["재생"].firstMatch
        XCTAssertTrue(playToggle.waitForExistence(timeout: 5), "재생 버튼")
        XCTAssertTrue(screen.contains(playToggle.frame),
                      "재생 버튼이 화면 밖: \(playToggle.frame)")

    }
}
