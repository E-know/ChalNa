import XCTest

/// 크롭 조정 플로우 시각 검증용 UI 테스트 (devMock 픽스처 사용, 사진 권한 불필요).
///
/// 각 체크포인트에서 `Thread.sleep` 으로 화면을 유지해, 호스트에서 `simctl io screenshot`
/// 폴링으로 프레임을 수집·검수할 수 있게 한다. XCTAttachment 스냅샷도 함께 남긴다.
///
/// 확대·축소·이동에 제약이 없으므로(러버밴드·스냅백 없음) 검증 대상은
/// "축소하면 검정 여백이 드러난다 · 캔버스 밖으로 밀어도 튕겨 돌아오지 않는다 · 초기화가 복구한다" 다.
final class CropAdjustUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAdjustFlow_FreeCrop_ZoomOut_Pan_Reset() throws {
        let app = XCUIApplication()
        app.launchEnvironment["CHALNA_APP_MODE"] = "devMock"
        app.launchArguments += ["-AppleLanguages", "(ko)"]
        app.launch()

        // 홈 → 새 Vlog
        let newVlog = app.buttons["새 Vlog 만들기"].firstMatch
        XCTAssertTrue(newVlog.waitForExistence(timeout: 10), "홈의 새 Vlog 버튼")
        newVlog.tap()

        // MediaPicker(dev fixtures) → 클립 2개 선택
        let firstAsset = app.buttons.matching(NSPredicate(format: "label CONTAINS '협재 바다'")).firstMatch
        XCTAssertTrue(firstAsset.waitForExistence(timeout: 10), "dev fixture: 협재 바다")
        firstAsset.tap()
        let secondAsset = app.buttons.matching(NSPredicate(format: "label CONTAINS '카페 테이블'")).firstMatch
        XCTAssertTrue(secondAsset.waitForExistence(timeout: 5), "dev fixture: 카페 테이블")
        secondAsset.tap()

        let confirm = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Timeline으로'")).firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "Timeline으로 버튼")
        confirm.tap()

        // 타임라인 편집 화면
        let adjustButton = app.buttons["조정"].firstMatch
        XCTAssertTrue(adjustButton.waitForExistence(timeout: 15), "타임라인 하단 조정 버튼")
        checkpoint(app, name: "10-timeline", holdSeconds: 3)

        // 조정 화면 진입
        adjustButton.tap()
        let hint = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '더블탭 = 초기화'")).firstMatch
        XCTAssertTrue(hint.waitForExistence(timeout: 10), "조정 화면 힌트 텍스트")
        checkpoint(app, name: "20-adjust-initial", holdSeconds: 3)

        // 캔버스 중심 좌표 (화면 중앙 부근이 캔버스 안쪽)
        let canvasCenter = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45))

        // 1) scale=1(딱 맞음)에서 우측으로 크게 드래그 —
        //    이동 제약이 없으므로 손을 떼도 스냅백 없이 그 자리에 머물러야 한다.
        //    (좌측에 검정 여백이 드러난 상태로 커밋된다.)
        let farRight = app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.45))
        canvasCenter.press(forDuration: 0.2, thenDragTo: farRight,
                           withVelocity: 300, thenHoldForDuration: 1.0)
        checkpoint(app, name: "30-panned-past-cover", holdSeconds: 3)

        // 2) 핀치 인(축소) → 사진이 캔버스보다 작아지고 사방에 검정 여백이 생긴다.
        app.pinch(withScale: 0.5, velocity: -1.0)
        checkpoint(app, name: "40-zoomed-out-with-margin", holdSeconds: 3)

        // 3) 축소 상태에서 좌측으로 드래그 → 제약 없이 그대로 이동
        let left = app.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.45))
        canvasCenter.press(forDuration: 0.2, thenDragTo: left,
                           withVelocity: 300, thenHoldForDuration: 1.0)
        checkpoint(app, name: "50-panned-while-shrunk", holdSeconds: 3)

        // 4) 회전 — 재클램프가 없어졌으므로 프레이밍(scale·offset)이 그대로 유지되어야 한다.
        let rotateButton = app.buttons["회전"].firstMatch
        XCTAssertTrue(rotateButton.waitForExistence(timeout: 5), "회전 버튼")
        rotateButton.tap()
        checkpoint(app, name: "55-rotated-keeps-framing", holdSeconds: 3)
        // 원위치(r0)로 3번 더 회전.
        for _ in 0..<3 { rotateButton.tap() }

        // 5) 더블탭 = 센터 크롭 리셋
        canvasCenter.doubleTap()
        checkpoint(app, name: "60-double-tap-reset", holdSeconds: 3)
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
