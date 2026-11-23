import XCTest

/// 문구 입력과 배치 단계의 키보드·도구 접근성을 실제 devMock 탐색 경로에서 확인한다.
final class LabelEditorUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLabelEditor_TwoStepFlow_ControlsReachable() throws {
        let app = XCUIApplication()
        app.launchEnvironment["CHALNA_APP_MODE"] = "devMock"
        app.launchArguments += ["-AppleLanguages", "(ko)"]
        app.launch()

        navigateToLabelEditor(app)

        // ── 스텝 1: 문구. 자막 입력을 탭하면 키보드가 올라온다.
        let textField = app.textFields.firstMatch
        XCTAssertTrue(textField.waitForExistence(timeout: 10), "자막 입력 필드")
        textField.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "스텝 1 에서 키보드가 올라오지 않음")

        // 스텝 1 에는 크기 슬라이더·배경 토글이 없어야 한다(문구 입력에만 집중).
        XCTAssertFalse(app.sliders.firstMatch.exists, "스텝 1 에 크기 슬라이더가 있으면 안 됨")
        XCTAssertFalse(app.switches.firstMatch.exists, "스텝 1 에 배경 토글이 있으면 안 됨")

        textField.typeText("제주 바다")

        let next = app.buttons["배치와 스타일"].firstMatch
        XCTAssertTrue(next.exists, "스텝 1 에 다음 버튼이 없음")
        XCTAssertTrue(next.isHittable, "키보드 ↑ 상태에서 다음 버튼을 탭할 수 없음")
        let close = app.buttons["뒤로"].firstMatch
        XCTAssertTrue(close.exists && close.isHittable, "키보드 ↑ 상태에서 닫기 버튼 도달 불가")

        // ── 스텝 2: 스타일. 키보드가 내려가고 배경 토글 + 크기 슬라이더가 나타난다.
        next.tap()

        let slider = app.sliders.firstMatch
        XCTAssertTrue(slider.waitForExistence(timeout: 5), "스텝 2 에 크기 슬라이더가 없음")
        XCTAssertTrue(slider.isHittable, "스텝 2 에서 크기 슬라이더를 탭할 수 없음")

        let backgroundToggle = app.switches.firstMatch
        XCTAssertTrue(backgroundToggle.exists, "스텝 2 에 배경 토글이 없음")
        XCTAssertTrue(backgroundToggle.isHittable, "스텝 2 에서 배경 토글을 탭할 수 없음")

        let save = app.buttons["자막 적용"].firstMatch
        XCTAssertTrue(save.exists && save.isHittable, "스텝 2 에서 저장 버튼 도달 불가")

        // 배경을 끄고 켜도 화면이 유지되어야 한다(라벨이 사라지거나 크래시하지 않는다).
        backgroundToggle.tap()
        XCTAssertTrue(slider.isHittable, "배경 OFF 후 슬라이더 도달 불가")
        backgroundToggle.tap()

        // ── 스텝 1 복귀: 뒤로 버튼 → 키보드 다시 ↑
        let back = app.buttons["뒤로"].firstMatch
        XCTAssertTrue(back.exists, "스텝 2 에 뒤로 버튼이 없음")
        back.tap()
        XCTAssertTrue(app.textFields.firstMatch.waitForExistence(timeout: 5), "스텝 1 복귀 실패")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "스텝 1 복귀 후 키보드가 올라오지 않음")
    }

    /// Task 13 이 `RootView` 에 건 전역 상한(`.dynamicTypeSize(...accessibility1)`)이
    /// `LabelEditorView`(`fullScreenCover`) 안까지 실제로 전달되는지 실측한다.
    /// 시스템 텍스트 크기를 accessibility5(상한보다 큰 값)로 강제하고, "크기" 캡션(footnote 역할 토큰)의
    /// 렌더 높이를 잰다 — 상한이 전달되면 accessibility1 수준에 머물고, 전달되지 않으면 accessibility5
    /// 수준까지 훨씬 커진다.
    func testLabelEditor_DynamicTypeAccessibility5_CapsAtAccessibility1() throws {
        let app = XCUIApplication()
        app.launchEnvironment["CHALNA_APP_MODE"] = "devMock"
        app.launchArguments += [
            "-AppleLanguages", "(ko)",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
        ]
        app.launch()

        navigateToLabelEditor(app)

        // "크기" 캡션은 스텝 2(스타일) 컨트롤이다 — 진입은 항상 스텝 1(문구)이므로 먼저 넘어간다.
        let next = app.buttons["배치와 스타일"].firstMatch
        XCTAssertTrue(next.waitForExistence(timeout: 10), "스텝 1 다음 버튼")
        next.tap()

        let sizeCaption = app.staticTexts["크기"].firstMatch
        XCTAssertTrue(sizeCaption.waitForExistence(timeout: 10), "\"크기\" 캡션")
        let height = sizeCaption.frame.height
        checkpoint(app, name: "t25-a11y5", holdSeconds: 3)

        // 정확한 pt 경계는 리포트에 기록 — 여기서는 회귀 감지용 방향성 assert만 건다.
        XCTAssertLessThan(
            height, 34,
            "\"크기\" 캡션이 accessibility5 수준까지 커짐(측정 \(height)pt) — 전역 Dynamic Type 상한이 fullScreenCover 로 전달되지 않는 것으로 보임"
        )
    }

    /// `[다음]` 을 누르지 않고 **키보드만 내려도** 위치·배경·크기 스텝으로 넘어간다.
    /// devMock 은 시각 검증 채널이 아니므로 도달성(exists/isHittable) 만 본다.
    func testLabelEditor_KeyboardDismiss_AdvancesToStyleStep() throws {
        let app = XCUIApplication()
        app.launchEnvironment["CHALNA_APP_MODE"] = "devMock"
        app.launchArguments += ["-AppleLanguages", "(ko)"]
        app.launch()

        navigateToLabelEditor(app)

        let textField = app.textFields.firstMatch
        XCTAssertTrue(textField.waitForExistence(timeout: 10), "자막 입력 필드")
        textField.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "스텝 1 키보드")
        XCTAssertFalse(app.sliders.firstMatch.exists, "스텝 1 에 크기 슬라이더가 있으면 안 됨")

        textField.typeText("제주 바다")
        // 리턴(.done)으로 키보드만 내린다 — `[다음]` 은 누르지 않는다.
        textField.typeText("\n")

        let slider = app.sliders.firstMatch
        XCTAssertTrue(slider.waitForExistence(timeout: 5),
                      "키보드 하강만으로 스텝 2(크기 슬라이더)에 도달하지 못했다")
        XCTAssertTrue(slider.isHittable, "자동 전환 후 크기 슬라이더를 탭할 수 없음")
        XCTAssertTrue(app.buttons["자막 적용"].firstMatch.exists, "자동 전환 후 저장 버튼 없음")
    }

    /// `.style` 스텝에서 두 손가락 확대/회전 후 크래시 없이 컨트롤에 도달하고 저장까지 되는지.
    /// devMock 은 시각 검증 채널이 아니므로 **기하 단언을 걸지 않는다** — 도달성·무크래시만 본다.
    func testLabelEditor_PinchAndRotate_NoCrashControlsReachable() throws {
        let app = XCUIApplication()
        app.launchEnvironment["CHALNA_APP_MODE"] = "devMock"
        app.launchArguments += ["-AppleLanguages", "(ko)"]
        app.launch()

        navigateToLabelEditor(app)

        let textField = app.textFields.firstMatch
        XCTAssertTrue(textField.waitForExistence(timeout: 10), "자막 입력 필드")
        textField.tap()
        textField.typeText("제주 바다")

        let next = app.buttons["배치와 스타일"].firstMatch
        XCTAssertTrue(next.exists && next.isHittable, "키보드 위 다음 버튼 도달 불가")
        next.tap()

        let slider = app.sliders.firstMatch
        XCTAssertTrue(slider.waitForExistence(timeout: 5), "스텝 2 크기 슬라이더")

        app.pinch(withScale: 1.5, velocity: 1.0)
        app.rotate(0.5, withVelocity: 1.0)

        XCTAssertTrue(slider.isHittable, "제스처 후 크기 슬라이더 도달 불가")
        let save = app.buttons["자막 적용"].firstMatch
        XCTAssertTrue(save.isHittable, "제스처 후 저장 버튼 도달 불가")
        save.tap()

        XCTAssertTrue(app.buttons["timeline.caption"].firstMatch.waitForExistence(timeout: 10),
                      "저장 후 타임라인 복귀 실패")
    }

    // MARK: - Helpers

    /// dev fixture 2개 선택 → Timeline → 하단 툴바 "라벨" 버튼으로 LabelEditorView 진입.
    private func navigateToLabelEditor(_ app: XCUIApplication) {
        let newVlog = app.buttons["home.newFilm"].firstMatch
        XCTAssertTrue(newVlog.waitForExistence(timeout: 10), "홈의 새 필름 버튼")
        newVlog.tap()

        let firstAsset = app.buttons.matching(NSPredicate(format: "label CONTAINS '협재 바다'")).firstMatch
        XCTAssertTrue(firstAsset.waitForExistence(timeout: 10), "dev fixture: 협재 바다")
        firstAsset.tap()
        let secondAsset = app.buttons.matching(NSPredicate(format: "label CONTAINS '카페 테이블'")).firstMatch
        XCTAssertTrue(secondAsset.waitForExistence(timeout: 5), "dev fixture: 카페 테이블")
        secondAsset.tap()

        let confirm = app.buttons["picker.confirm"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "편집으로 이동하는 버튼")
        confirm.tap()

        let labelButton = app.buttons["timeline.caption"].firstMatch
        XCTAssertTrue(labelButton.waitForExistence(timeout: 15), "타임라인 하단 라벨 버튼")
        labelButton.tap()
    }

    /// XCTAttachment 스냅샷 + 호스트 폴링용 대기.
    private func checkpoint(_ app: XCUIApplication, name: String, holdSeconds: TimeInterval) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
        Thread.sleep(forTimeInterval: holdSeconds)
    }
}
