import XCTest

/// 크롭 조정 플로우 시각 검증용 UI 테스트 (devMock 픽스처 사용, 사진 권한 불필요).
///
/// 각 체크포인트에서 `Thread.sleep` 으로 화면을 유지해, 호스트에서 `simctl io screenshot`
/// 폴링으로 프레임을 수집·검수할 수 있게 한다(러버밴드 오버슛은 드래그 hold 중에만 보인다).
/// XCTAttachment 스냅샷도 함께 남긴다(안정 상태 백업).
final class CropAdjustUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAdjustFlow_CenterCrop_RubberBand_Reset() throws {
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

        // 1) scale=1(딱 맞음)에서 우측으로 크게 드래그 + hold —
        //    이동 한계 0 → 러버밴드 오버슛 + 3분할 그리드가 hold 동안 보여야 한다.
        let farRight = app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.45))
        canvasCenter.press(forDuration: 0.2, thenDragTo: farRight,
                           withVelocity: 300, thenHoldForDuration: 2.5)
        // 릴리즈 직후: 스프링 스냅백으로 원위치 복귀.
        checkpoint(app, name: "30-after-rubberband-release", holdSeconds: 3)

        // 2) 핀치 줌(2배) → 크롭 이동 여지 생김
        app.pinch(withScale: 2.0, velocity: 1.0)
        checkpoint(app, name: "40-zoomed", holdSeconds: 3)

        // 3) 줌 상태에서 좌측으로 드래그 → 정상 크롭 이동 후 커밋
        let left = app.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.45))
        canvasCenter.press(forDuration: 0.2, thenDragTo: left,
                           withVelocity: 300, thenHoldForDuration: 1.0)
        checkpoint(app, name: "50-panned-zoomed", holdSeconds: 3)

        // 4) 더블탭 = 센터 크롭 리셋
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
