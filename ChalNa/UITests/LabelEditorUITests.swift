import XCTest

/// 라벨 에디터 2스텝 플로우 도달성 + 키보드 도달성 회귀 테스트 (devMock 픽스처 사용, 사진 권한 불필요).
/// devMock 은 시각 검증 채널이 아니다 — 여기 assertion 은 존재/탭 가능 여부(exists/isHittable)뿐이고
/// 화면 내용(색·기하)은 보지 않는다.
///
/// Task 16 이 미해결로 남긴 질문 — 키보드가 올라온 상태에서 주 컨트롤(크기 슬라이더·저장/닫기)이
/// 여전히 화면 안에 있고 탭 가능한가 — 을 XCUITest 의 합성 키보드 입력(`typeText`)으로 검증한다.
///
/// **정정 기록(fix round 1):** 최초 작성 시 `KeyboardObserver.apply(_:)` 에 `print` 계측을 넣고
/// `xcodebuild test` 의 표준출력에서 0회 호출을 확인해 "이 시뮬레이터에서는 키보드 알림이 전혀
/// 발생하지 않는다"고 잘못 결론지었다. 이후 밝혀진 바로는, **App-under-test 프로세스의 `print`
/// 출력 자체가 UI 테스트를 구동하는 `xcodebuild`(또는 통합 로그)에 전혀 도달하지 않는다** —
/// 무조건 실행되는 print 로도 0건이 확인되어 계측 채널 자체가 무효였다(신호 부재가 곧 "notification
/// 없음"을 뜻하지 않았다). 파일 기반 계측(App Documents 디렉터리에 직접 기록 후
/// `xcrun simctl get_app_container`로 호스트에서 읽기)으로 다시 확인한 결과,
/// `keyboardWillChangeFrameNotification` 은 **실제로 발생**하며 `keyboard.height` 도 실측
/// 260pt(iPhone SE)·335pt(iPhone 17/17 Pro)의 실질적인 값에 도달한다 — 즉 슬라이더를 키보드 위로
/// 띄우는 코드 경로(`step == .text && keyboard.height > 0`)가 **실제로 실행된다**. `bottomControls`
/// 자체에 붙인 별도 프로브로도 이 안전영역이 260pt만큼 커지는 것을 확인했다. (다만 온스크린 소프트
/// 키보드 그래픽 자체는 스크린샷에 나타나지 않는다 — 여전한 시뮬레이터 특성이지만 레이아웃 반응과는
/// 무관하다.) 단, `XCUIElement.frame`으로 슬라이더의 정확한 상승폭(pt)을 재는 것은 `.safeAreaInset`
/// + `.ignoresSafeArea(.keyboard)` + 이중 `.animation(value:)` 상호작용 때문에 애니메이션 중간
/// 프레임을 다시 집어내는 등 불안정했다 — 그래서 아래 테스트는 그 수치 assert 대신 도달성(exists/
/// isHittable) assert 와 XCTContext 액티비티 로그로 이 정정된 사실을 CI 출력에 남긴다.
/// **정정 기록(라벨 accessory):** 문구 스텝의 `[다음]` 을 키보드 위로 옮길 때
/// `ToolbarItemGroup(placement: .keyboard)` 를 먼저 시도했으나, 이 화면(`NavigationStack` 없는
/// `fullScreenCover` 콘텐츠)에서는 **아무것도 렌더되지 않았다** — 커버 루트와 포커스된 TextField
/// 양쪽에 붙여 각각 확인했고, XCUITest 요소 덤프가 `toolbars=0` · `다음` 버튼 부재였다.
/// 그래서 `KeyboardObserver.height` 로 직접 올리는 SwiftUI 바(`nextAccessoryBar`)를 쓴다.
final class LabelEditorUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// 스텝 1(문구) 진입 → `[다음]` → 스텝 2(스타일) 컨트롤 도달성 → `[‹]` 로 복귀.
    ///
    /// `[다음]` 은 상단바가 아니라 **키보드 바로 위 accessory 바**에 있다(`nextAccessoryBar`).
    /// 아래 assert 는 존재/탭 가능만 보므로 위치와 무관하게 유효하다 — 오히려 키보드에 가려지지
    /// 않는지가 이 테스트의 핵심이다.
    ///
    /// 클래스 doc 의 계측 정정 기록 참고: 키보드 알림은 실제로 발생하고 `keyboard.height` 도
    /// 실측값(SE 260pt / 17 계열 335pt)에 도달한다. 다만 소프트 키보드 그래픽은 스크린샷에
    /// 나타나지 않고, `XCUIElement.frame` 으로 정확한 상승폭(pt)을 재는 것은 불안정하다 —
    /// 그래서 수치 assert 대신 도달성(exists/isHittable) assert 를 쓴다.
    func testLabelEditor_TwoStepFlow_ControlsReachable() throws {
        let app = XCUIApplication()
        app.launchEnvironment["CHALNA_APP_MODE"] = "devMock"
        app.launchArguments += ["-AppleLanguages", "(ko)"]
        app.launch()

        navigateToLabelEditor(app)

        // ── 스텝 1: 문구. 진입은 항상 문구 스텝이며 키보드가 올라와 있어야 한다.
        let textField = app.textFields.firstMatch
        XCTAssertTrue(textField.waitForExistence(timeout: 10), "라벨 인라인 TextField")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "스텝 1 에서 키보드가 올라오지 않음")

        XCTContext.runActivity(
            named: "키보드 알림 실측 정정: keyboardWillChangeFrameNotification 발생 확인됨(SE 260pt/17계열 335pt) — Task 16 잔여 질문 해소, 최초 'not captured' 결론은 계측 채널 오류였음"
        ) { _ in }

        // 스텝 1 에는 크기 슬라이더·배경 토글이 없어야 한다(문구 입력에만 집중).
        XCTAssertFalse(app.sliders.firstMatch.exists, "스텝 1 에 크기 슬라이더가 있으면 안 됨")
        XCTAssertFalse(app.switches.firstMatch.exists, "스텝 1 에 배경 토글이 있으면 안 됨")

        textField.typeText("제주 바다")

        let next = app.buttons["다음"].firstMatch
        XCTAssertTrue(next.exists, "스텝 1 에 다음 버튼이 없음")
        XCTAssertTrue(next.isHittable, "키보드 ↑ 상태에서 다음 버튼을 탭할 수 없음")
        let close = app.buttons["닫기"].firstMatch
        XCTAssertTrue(close.exists && close.isHittable, "키보드 ↑ 상태에서 닫기 버튼 도달 불가")

        // ── 스텝 2: 스타일. 키보드가 내려가고 배경 토글 + 크기 슬라이더가 나타난다.
        next.tap()

        let slider = app.sliders.firstMatch
        XCTAssertTrue(slider.waitForExistence(timeout: 5), "스텝 2 에 크기 슬라이더가 없음")
        XCTAssertTrue(slider.isHittable, "스텝 2 에서 크기 슬라이더를 탭할 수 없음")

        let backgroundToggle = app.switches.firstMatch
        XCTAssertTrue(backgroundToggle.exists, "스텝 2 에 배경 토글이 없음")
        XCTAssertTrue(backgroundToggle.isHittable, "스텝 2 에서 배경 토글을 탭할 수 없음")

        let save = app.buttons["저장"].firstMatch
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
        let next = app.buttons["다음"].firstMatch
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
        XCTAssertTrue(textField.waitForExistence(timeout: 10), "라벨 인라인 TextField")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "스텝 1 키보드")
        XCTAssertFalse(app.sliders.firstMatch.exists, "스텝 1 에 크기 슬라이더가 있으면 안 됨")

        textField.typeText("제주 바다")
        // 리턴(.done)으로 키보드만 내린다 — `[다음]` 은 누르지 않는다.
        textField.typeText("\n")

        let slider = app.sliders.firstMatch
        XCTAssertTrue(slider.waitForExistence(timeout: 5),
                      "키보드 하강만으로 스텝 2(크기 슬라이더)에 도달하지 못했다")
        XCTAssertTrue(slider.isHittable, "자동 전환 후 크기 슬라이더를 탭할 수 없음")
        XCTAssertTrue(app.buttons["저장"].firstMatch.exists, "자동 전환 후 저장 버튼 없음")
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
