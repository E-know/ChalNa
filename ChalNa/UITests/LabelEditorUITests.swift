import XCTest

/// 라벨 에디터 시각 검증 + 텍스트 입력 플로우 회귀 테스트 (devMock 픽스처 사용, 사진 권한 불필요).
///
/// Task 16 이 미해결로 남긴 질문 — 키보드가 올라온 상태에서 주 컨트롤(크기 슬라이더·저장/닫기)이
/// 여전히 화면 안에 있고 탭 가능한가 — 을 XCUITest 의 합성 키보드 입력(`typeText`)으로 검증하려 시도했다.
///
/// **알아낸 것(중요, "not captured"):** 이 시뮬레이터(Xcode/iOS 26.5, iPhone SE 3rd gen)에서
/// XCUITest 의 `typeText` 로 입력하면 `UIResponder.keyboardWillChangeFrameNotification` 이 전혀
/// 발생하지 않는다 — `KeyboardObserver.apply(_:)` 에 임시로 print 계측을 넣어 확인했다(0회 호출).
/// `ConnectHardwareKeyboard` 를 끄고 시뮬레이터/디바이스를 완전히 재부팅해도 동일했고, 온스크린
/// 소프트 키보드도 스크린샷에 전혀 나타나지 않았다 — XCUITest 의 키 이벤트 주입이 시뮬레이터에서
/// "하드웨어 키보드"로 취급되는 것으로 보인다(잘 알려진 시뮬레이터 한계). 결과적으로
/// `LabelEditorView.keyboard.height` 는 이 테스트 내내 0 으로 남아, 슬라이더/저장/닫기를 키보드
/// 위로 띄우는 코드 경로(`phase == .editing && keyboard.height > 0`)가 전혀 실행되지 않는다.
/// 즉 아래 도달성 assert 들은 **일반 레이아웃에서의 도달성만 증명**하며, 키보드 회피 로직 자체는
/// 이 하니스로 검증하지 못했다 — Task 16 의 잔여 질문은 여전히 실기기 QA 가 필요하다.
final class LabelEditorUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// 라벨 에디터 진입(EDIT) → 슬라이더/저장/닫기 도달성 확인 → 텍스트 입력·제출(IDLE 복귀).
    /// (키보드 회피 로직 자체는 검증하지 못함 — 클래스 doc 참고.)
    func testLabelEditor_TextInputFlow_ControlsRemainReachable() throws {
        let app = XCUIApplication()
        app.launchEnvironment["CHALNA_APP_MODE"] = "devMock"
        app.launchArguments += ["-AppleLanguages", "(ko)"]
        app.launch()

        navigateToLabelEditor(app)

        // 클립에 저장된 라벨이 없으면 reflow() 가 즉시 .editing 으로 진입 → 텍스트 입력 세션이 시작된다.
        let textField = app.textFields.firstMatch
        XCTAssertTrue(textField.waitForExistence(timeout: 10), "라벨 인라인 TextField")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "텍스트 입력 세션이 시작되지 않음")

        // EDIT 상태에서 주 컨트롤 도달성 확인.
        let slider = app.sliders.firstMatch
        XCTAssertTrue(slider.exists, "EDIT 상태에서 크기 슬라이더가 존재하지 않음")
        XCTAssertTrue(slider.isHittable, "EDIT 상태에서 크기 슬라이더를 탭할 수 없음")

        let save = app.buttons["저장"].firstMatch
        XCTAssertTrue(save.exists, "EDIT 상태에서 저장 버튼이 존재하지 않음")
        XCTAssertTrue(save.isHittable, "EDIT 상태에서 저장 버튼을 탭할 수 없음")

        let close = app.buttons["닫기"].firstMatch
        XCTAssertTrue(close.exists, "EDIT 상태에서 닫기 버튼이 존재하지 않음")
        XCTAssertTrue(close.isHittable, "EDIT 상태에서 닫기 버튼을 탭할 수 없음")

        checkpoint(app, name: "t25-se-editing", holdSeconds: 3)

        // 텍스트 입력 후 제출 → IDLE 로 전환.
        textField.typeText("제주 바다")
        textField.typeText("\n")   // submitLabel(.done) → onSubmit { focused = false } → phase = .idle

        let keyboardGone = NSPredicate(format: "exists == false")
        expectation(for: keyboardGone, evaluatedWith: app.keyboards.firstMatch, handler: nil)
        waitForExpectations(timeout: 5)

        checkpoint(app, name: "t25-se-idle", holdSeconds: 3)
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

    // MARK: - Helpers

    /// dev fixture 2개 선택 → Timeline → 하단 툴바 "라벨" 버튼으로 LabelEditorView 진입.
    private func navigateToLabelEditor(_ app: XCUIApplication) {
        let newVlog = app.buttons["새 Vlog 만들기"].firstMatch
        XCTAssertTrue(newVlog.waitForExistence(timeout: 10), "홈의 새 Vlog 버튼")
        newVlog.tap()

        let firstAsset = app.buttons.matching(NSPredicate(format: "label CONTAINS '협재 바다'")).firstMatch
        XCTAssertTrue(firstAsset.waitForExistence(timeout: 10), "dev fixture: 협재 바다")
        firstAsset.tap()
        let secondAsset = app.buttons.matching(NSPredicate(format: "label CONTAINS '카페 테이블'")).firstMatch
        XCTAssertTrue(secondAsset.waitForExistence(timeout: 5), "dev fixture: 카페 테이블")
        secondAsset.tap()

        let confirm = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Timeline으로'")).firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "Timeline으로 버튼")
        confirm.tap()

        let labelButton = app.buttons["라벨"].firstMatch
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
