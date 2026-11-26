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

    func testTrimLivePhotoAndReopenSavedRange() throws {
        let app = openTimeline()
        let livePhoto = app.collectionViews.firstMatch.descendants(matching: .any)
            .matching(identifier: "timeline.clip.0").firstMatch
        XCTAssertTrue(livePhoto.waitForExistence(timeout: 10))
        XCTAssertTrue(livePhoto.label.contains("라이브 포토"))
        livePhoto.tap()
        let untrimmedLabel = livePhoto.label

        let trim = app.buttons["timeline.trim"]
        XCTAssertTrue(trim.waitForExistence(timeout: 5))
        trim.tap()
        let elements = app.descendants(matching: .any)
        let start = elements.matching(identifier: "trim.start").firstMatch
        let end = elements.matching(identifier: "trim.end").firstMatch
        let done = app.buttons["trim.done"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        XCTAssertTrue(done.wait(for: \.isEnabled, toEqual: true, timeout: 10))
        let initialStart = try XCTUnwrap(start.value as? String)
        let initialEnd = try XCTUnwrap(end.value as? String)
        let distance = (end.frame.midX - start.frame.midX) * 0.20
        drag(start, by: distance)
        drag(end, by: -distance)
        let savedStart = try XCTUnwrap(start.value as? String)
        let savedEnd = try XCTUnwrap(end.value as? String)
        XCTAssertNotEqual(savedStart, initialStart)
        XCTAssertNotEqual(savedEnd, initialEnd)

        done.tap()
        XCTAssertTrue(trim.waitForExistence(timeout: 10))
        XCTAssertNotEqual(livePhoto.label, untrimmedLabel)
        XCTAssertTrue(livePhoto.label.contains("라이브 포토"))
        trim.tap()
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        XCTAssertEqual(start.value as? String, savedStart)
        XCTAssertEqual(end.value as? String, savedEnd)
    }

    func testTrimVideoFromBothEndsAndCancelSubsequentChanges() {
        let app = openTimeline()
        let window = app.windows.firstMatch
        // 펼친 시뮬레이터의 안쪽 디스플레이 회전은 Device Hub가 제어한다.
        let unfolded = min(window.frame.width, window.frame.height) >= 600
        if !unfolded { XCUIDevice.shared.orientation = .portrait }
        defer { if !unfolded { XCUIDevice.shared.orientation = .portrait } }
        let trim = app.buttons["timeline.trim"]
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
        let screen = window.frame
        for id in ["trim.cancel", "trim.done"] {
            let inNavigation = app.navigationBars.buttons[id].firstMatch
            let inToolbar = app.toolbars.buttons[id].firstMatch
            XCTAssertTrue((inNavigation.exists && inNavigation.isHittable) || (inToolbar.exists && inToolbar.isHittable),
                          "\(id)는 시스템 탐색 항목이어야 한다")
        }
        if unfolded {
            XCTAssertLessThan(start.frame.minX, screen.minX + screen.width * 0.2)
            XCTAssertGreaterThan(end.frame.maxX, screen.maxX - screen.width * 0.2)
            XCTAssertGreaterThan(start.frame.midY, screen.minY + screen.height * 0.75)
            XCTAssertEqual(start.frame.midY, end.frame.midY, accuracy: 2)
            let cancel = app.buttons["trim.cancel"].frame
            if screen.width > screen.height {
                XCTAssertGreaterThan(abs(cancel.midX - screen.midX), screen.width * 0.3)
                XCTAssertEqual(cancel.midX, done.frame.midX, accuracy: 25, "두 항목을 같은 시스템 세로 막대에 배치한다")
                XCTAssertLessThan(cancel.midY, done.frame.midY)
            } else {
                XCTAssertLessThan(cancel.midX, screen.minX + screen.width * 0.2)
                XCTAssertGreaterThan(done.frame.midX, screen.midX)
                XCTAssertGreaterThan(done.frame.midX - cancel.midX, screen.width * 0.6)
                XCTAssertEqual(cancel.midY, done.frame.midY, accuracy: 4)
                XCTAssertLessThan(cancel.midY, screen.minY + screen.height * 0.15)
            }
        }
        let initialStart = start.value as? String
        let initialEnd = end.value as? String
        let distance = (end.frame.midX - start.frame.midX) * 0.24
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

        if !unfolded {
            XCUIDevice.shared.orientation = .landscapeLeft
            let landscape = NSPredicate { _, _ in window.frame.width > window.frame.height }
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: landscape, object: nil)], timeout: 8), .completed)
        }
        for control in [start, end, done, app.buttons["trim.cancel"]] {
            XCTAssertTrue(control.isHittable)
            XCTAssertTrue(app.windows.firstMatch.frame.contains(control.frame))
        }
    }

    func testTrimAddsSeparateClipsFromOneVideo() throws {
        let app = openTimeline(videoTitle: "노을 산책")
        let cells = app.collectionViews.firstMatch.descendants(matching: .any)
        let source = cells.matching(identifier: "timeline.clip.1").firstMatch
        let first = cells.matching(identifier: "timeline.clip.2").firstMatch
        let second = cells.matching(identifier: "timeline.clip.3").firstMatch
        XCTAssertTrue(source.waitForExistence(timeout: 10))
        let originalLabel = source.label
        source.tap()

        let trim = app.buttons["timeline.trim"]
        let addClip = app.buttons["trim.add"]
        let elements = app.descendants(matching: .any)
        let start = elements.matching(identifier: "trim.start").firstMatch
        let end = elements.matching(identifier: "trim.end").firstMatch
        trim.tap()
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["trim.done"].wait(for: \.isEnabled, toEqual: true, timeout: 10))
        let initialEnd = try XCTUnwrap(end.value as? String)
        let width = end.frame.midX - start.frame.midX
        drag(start, by: width * 0.10)
        drag(end, by: -width * 0.52)
        let firstStart = try XCTUnwrap(start.value as? String)
        let firstEnd = try XCTUnwrap(end.value as? String)
        XCTAssertLessThan(firstEnd, initialEnd)
        XCTAssertTrue(addClip.wait(for: \.isEnabled, toEqual: true, timeout: 5))
        let trimScreenshot = XCTAttachment(screenshot: app.screenshot())
        trimScreenshot.name = "trim-add-clip"
        trimScreenshot.lifetime = .keepAlways
        add(trimScreenshot)
        addClip.tap()

        XCTAssertTrue(first.wait(for: \.isSelected, toEqual: true, timeout: 10))
        XCTAssertEqual(source.label, originalLabel)
        trim.tap()
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["trim.done"].wait(for: \.isEnabled, toEqual: true, timeout: 10))
        XCTAssertEqual(start.value as? String, firstStart)
        XCTAssertEqual(end.value as? String, firstEnd)
        drag(end, by: width * 0.54)
        XCTAssertEqual(end.value as? String, initialEnd)
        drag(start, by: width * 0.48)
        let secondStart = try XCTUnwrap(start.value as? String)
        XCTAssertGreaterThan(secondStart, firstEnd)
        addClip.tap()

        XCTAssertTrue(second.wait(for: \.isSelected, toEqual: true, timeout: 10))
        XCTAssertEqual(source.label, originalLabel)
        let timelineScreenshot = XCTAttachment(screenshot: app.screenshot())
        timelineScreenshot.name = "timeline-with-two-new-clips"
        timelineScreenshot.lifetime = .keepAlways
        add(timelineScreenshot)
        trim.tap()
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        XCTAssertEqual(start.value as? String, secondStart)
        XCTAssertEqual(end.value as? String, initialEnd)
        app.buttons["trim.cancel"].tap()

        app.buttons["timeline.export"].tap()
        let exportCount = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH '클립 4개'")).firstMatch
        XCTAssertTrue(exportCount.waitForExistence(timeout: 10))
    }

    func testTrimPlayheadScrubsAndPlaysWithinSelection() throws {
        let app = openTimeline(videoTitle: "노을 산책")
        app.collectionViews.firstMatch.descendants(matching: .any)
            .matching(identifier: "timeline.clip.1").firstMatch.tap()
        app.buttons["timeline.trim"].tap()

        let elements = app.descendants(matching: .any)
        let head = elements.matching(identifier: "trim.playhead").firstMatch
        let start = elements.matching(identifier: "trim.start").firstMatch
        let end = elements.matching(identifier: "trim.end").firstMatch
        let play = app.buttons["trim.play"]
        XCTAssertTrue(head.waitForExistence(timeout: 10))
        XCTAssertTrue(play.wait(for: \.isEnabled, toEqual: true, timeout: 10))
        let paused = play.label
        XCTAssertEqual(head.value as? String, start.value as? String)

        let width = end.frame.midX - start.frame.midX
        drag(start, by: width * 0.10)
        let selectedStart = try XCTUnwrap(start.value as? String)
        XCTAssertEqual(head.value as? String, selectedStart)
        drag(end, by: -width * 0.10)
        let selectedEnd = try XCTUnwrap(end.value as? String)
        XCTAssertEqual(head.value as? String, selectedEnd)
        let duration = app.staticTexts["trim.duration"]
        let selectedDuration = duration.label

        drag(head, by: -width * 0.40)
        let scrubbed = try XCTUnwrap(head.value as? String)
        XCTAssertGreaterThan(scrubbed, selectedStart)
        XCTAssertLessThan(scrubbed, selectedEnd)
        XCTAssertEqual(start.value as? String, selectedStart)
        XCTAssertEqual(end.value as? String, selectedEnd)
        XCTAssertEqual(play.label, paused)
        play.tap()
        var playingTime = try XCTUnwrap(head.value as? String)
        XCTAssertGreaterThanOrEqual(playingTime, scrubbed)
        let deadline = Date.now.addingTimeInterval(2)
        while playingTime == scrubbed && Date.now < deadline {
            Thread.sleep(forTimeInterval: 0.05)
            playingTime = try XCTUnwrap(head.value as? String)
        }
        XCTAssertGreaterThan(playingTime, scrubbed)
        XCTAssertLessThan(playingTime, selectedEnd)
        let stopped = NSPredicate { _, _ in head.value as? String == selectedEnd && play.label == paused }
        expectation(for: stopped, evaluatedWith: nil)
        waitForExpectations(timeout: 5)

        play.tap()
        let restarted = try XCTUnwrap(head.value as? String)
        XCTAssertGreaterThanOrEqual(restarted, selectedStart)
        XCTAssertLessThan(restarted, scrubbed)
        XCTAssertNotEqual(play.label, paused)
        XCTAssertEqual(start.value as? String, selectedStart)
        XCTAssertEqual(end.value as? String, selectedEnd)
        XCTAssertEqual(duration.label, selectedDuration)
    }

    private func drag(_ handle: XCUIElement, by dx: CGFloat) {
        let point = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        point.press(forDuration: 0.15, thenDragTo: point.withOffset(CGVector(dx: dx, dy: 0)))
    }

    private func openTimeline(videoTitle: String = "카페 테이블") -> XCUIApplication {
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
        let secondAsset = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", videoTitle)).firstMatch
        XCTAssertTrue(secondAsset.waitForExistence(timeout: 5), "dev fixture: \(videoTitle)")
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
