import XCTest

/// 크롭 조정 화면의 **도달성·무크래시 스모크 테스트** (devMock 픽스처 사용, 사진 권한 불필요).
///
/// - 이 테스트가 보증하는 것은 "조정 화면에 도달하고, 드래그·핀치·회전·더블탭 제스처를 실행해도
///   크래시 없이 컨트롤이 계속 살아 있다" 뿐이다. **시각/기하 계약(여백이 검정으로 보이는지,
///   프레이밍이 유지되는지 등)은 검증하지 않는다** — assertion 은 버튼·힌트 텍스트의 존재
///   확인(`waitForExistence`)뿐이고 화면 내용은 보지 않는다.
/// - devMock 픽스처는 실제 미디어(사진 라이브러리)와 너무 달라 시각 검증 채널로 쓰지 않는다
///   (사용자 지시). 실제 시각 검증은 사용자가 실제 사진 라이브러리로 별도 진행한다.
/// - 기하·여백 계약은 유닛 테스트가 담당한다: `CompositionServiceTests/ClipFramingTests`
///   (offset 이 제약 없이 반영되는지, 축소 시 결과 사각형이 캔버스보다 작아지는지)와
///   `CompositionServiceTests/CompositorRenderTests`(실제 export 프레임을 픽셀 샘플링해
///   축소 여백이 검정인지 확인).
/// - **실측 기록**: 이 파일의 이전 버전으로 아래 제스처 시퀀스를 2회 독립 실행한 결과,
///   핀치(`withScale: 0.5`, 손가락을 모으는 축소 방향) 이후의 체크포인트(`40-after-pinch-in`,
///   `50-after-drag-left`)가 그 앞 체크포인트(`30-after-drag-right`)와 스크린샷이 바이트
///   단위로 완전히 동일했다(2회 모두 재현). **원인은 확정되지 않았다.** 부분 설명은 있다 —
///   dev fixture 4개(`Modules/PhotosService/Resources/DevFixtures/*.mp4`)는 640×360 가로
///   (16:9)라 1080×1920 캔버스에서 `fillScale = max(1080/640, 1920/360) = 5.3333`
///   (3413.33×1920)이 되고, 옛 `maxOffsetFraction`(scale 1 기준)이 (1.08025, 0)이라
///   세로 방향 여유가 정확히 0 이었다(세로 무변화는 이걸로 설명됨). 또한 옛 `ClipAdjustView`
///   는 핀치를 `min(max(scale, 1.0), 4.0)` 로 클램프해 `app.pinch(withScale: 0.5)` 가
///   scale 1.0 으로 커밋됐다(핀치 체크포인트 무변화는 이걸로 설명됨). 하지만 **두 번째(가로)
///   드래그**(`50-after-drag-left`) 이후에도 동일했던 것은 이 둘로 설명되지 않는다(가로
///   방향은 여유가 있었다) — 그래서 "XCUITest 합성 제스처가 뷰에 관측 가능한 변화를 못
///   만든다"는 결론은 근거가 없다. 다음 사람이 같은 조사를 반복하지 않도록 남겨둔다.
///
/// 각 체크포인트에서 `Thread.sleep` 으로 화면을 유지해, 호스트에서 `simctl io screenshot`
/// 폴링으로 프레임을 수집할 수 있게 한다. XCTAttachment 스냅샷도 함께 남긴다.
final class CropAdjustUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAdjustFlow_SurvivesGestureRotationAndReset() throws {
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

        // 1) 우측으로 크게 드래그한다.
        let farRight = app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.45))
        canvasCenter.press(forDuration: 0.2, thenDragTo: farRight,
                           withVelocity: 300, thenHoldForDuration: 1.0)
        checkpoint(app, name: "30-after-drag-right", holdSeconds: 3)

        // 2) 핀치 인(손가락을 모으는 축소) 제스처를 실행한다.
        app.pinch(withScale: 0.5, velocity: -1.0)
        checkpoint(app, name: "40-after-pinch-in", holdSeconds: 3)

        // 3) 좌측으로 드래그한다.
        let left = app.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.45))
        canvasCenter.press(forDuration: 0.2, thenDragTo: left,
                           withVelocity: 300, thenHoldForDuration: 1.0)
        checkpoint(app, name: "50-after-drag-left", holdSeconds: 3)

        // 4) 회전 버튼을 탭한다.
        let rotateButton = app.buttons["회전"].firstMatch
        XCTAssertTrue(rotateButton.waitForExistence(timeout: 5), "회전 버튼")
        rotateButton.tap()
        checkpoint(app, name: "55-after-rotate", holdSeconds: 3)
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
