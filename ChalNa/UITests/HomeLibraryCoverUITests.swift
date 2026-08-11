import XCTest

/// devMock 으로 필름을 실제로 만들어(선택 → Timeline → export) 홈에 돌아왔을 때
/// 라이브러리에 포스터가 나타나는지 확인한다 — export → 라이브러리 저장 → 홈 노출의
/// 유일한 엔드투엔드 검증이자, 표지(합성 결과물 첫 프레임, 9:16) 시각 검증용 스크린샷 소스.
final class HomeLibraryCoverUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testExportedFilmAppearsInHomeLibrary() throws {
        let app = XCUIApplication()
        app.launchEnvironment["CHALNA_APP_MODE"] = "devMock"
        app.launchArguments += ["-AppleLanguages", "(ko)"]
        app.launch()

        // 홈 → 새 Vlog
        let newVlog = app.buttons["새 Vlog 만들기"].firstMatch
        XCTAssertTrue(newVlog.waitForExistence(timeout: 10), "홈의 새 Vlog 버튼")
        newVlog.tap()

        // dev fixture 2개 선택 → Timeline
        let firstAsset = app.buttons.matching(NSPredicate(format: "label CONTAINS '협재 바다'")).firstMatch
        XCTAssertTrue(firstAsset.waitForExistence(timeout: 10), "dev fixture: 협재 바다")
        firstAsset.tap()
        let secondAsset = app.buttons.matching(NSPredicate(format: "label CONTAINS '카페 테이블'")).firstMatch
        XCTAssertTrue(secondAsset.waitForExistence(timeout: 5), "dev fixture: 카페 테이블")
        secondAsset.tap()

        let confirm = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Timeline으로'")).firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "Timeline으로 버튼")
        confirm.tap()

        // Timeline → 저장 (Export 진입 + 합성 시작)
        let save = app.buttons["저장"].firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: 15), "Timeline 저장 버튼")
        save.tap()

        // Export 완료(홈으로) 또는 쿼터 차단(다시 시도) 대기.
        // 완료 시 사진 보관함 자동 저장이 돌아 fresh 설치에서는 시스템 권한 알럿이
        // 화면을 덮는다 — 닫지 않으면 이후 모든 탭을 알럿이 가로챈다.
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let goHome = app.buttons["홈으로"].firstMatch
        let retry = app.buttons["다시 시도"].firstMatch
        let deadline = Date().addingTimeInterval(120)
        while Date() < deadline, !goHome.exists, !retry.exists {
            dismissPhotoPermissionAlert(springboard: springboard)
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }
        if retry.exists {
            throw XCTSkip("export 쿼터(하루 1회) 소진 — 시뮬레이터 앱 데이터를 지우고 다시 실행")
        }
        XCTAssertTrue(goHome.exists, "Export 가 120초 안에 완료되지 않았다")
        dismissPhotoPermissionAlert(springboard: springboard)
        goHome.tap()

        // 홈 라이브러리에 방금 만든 필름 포스터가 있어야 한다 (메타 라벨 "2 CLIPS · mm:ss").
        let poster = app.buttons.matching(NSPredicate(format: "label CONTAINS 'CLIPS'")).firstMatch
        XCTAssertTrue(poster.waitForExistence(timeout: 10), "홈 라이브러리 필름 포스터")

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "home-library-cover"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// 사진 보관함 권한 시스템 알럿이 떠 있으면 허용으로 닫는다 (ko/en 시스템 언어 모두).
    private func dismissPhotoPermissionAlert(springboard: XCUIApplication) {
        let allow = springboard.alerts.buttons.matching(NSPredicate(
            format: "label IN {'허용', 'Allow', '모든 사진에 대한 접근 허용', 'Allow Access to All Photos'}"
        )).firstMatch
        if allow.exists {
            allow.tap()
        }
    }
}
