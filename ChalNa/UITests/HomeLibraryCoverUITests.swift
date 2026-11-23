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
        let newVlog = app.buttons["home.newFilm"].firstMatch
        XCTAssertTrue(newVlog.waitForExistence(timeout: 10), "홈의 새 Vlog 버튼")
        newVlog.tap()

        let filmTitle = "필름 " + UUID().uuidString.prefix(8)
        let title = app.textFields["picker.title"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText(filmTitle + "\n")

        // dev fixture 2개 선택 → Timeline
        let firstAsset = app.buttons.matching(NSPredicate(format: "label CONTAINS '협재 바다'")).firstMatch
        XCTAssertTrue(firstAsset.waitForExistence(timeout: 10), "dev fixture: 협재 바다")
        firstAsset.tap()
        let secondAsset = app.buttons.matching(NSPredicate(format: "label CONTAINS '카페 테이블'")).firstMatch
        XCTAssertTrue(secondAsset.waitForExistence(timeout: 5), "dev fixture: 카페 테이블")
        secondAsset.tap()

        let confirm = app.buttons.matching(identifier: "picker.confirm").firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "Timeline으로 버튼")
        confirm.tap()

        // Timeline → 저장 (Export 진입 + 합성 시작)
        let save = app.buttons["timeline.export"].firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: 15), "Timeline 저장 버튼")
        save.tap()
        let startExport = app.buttons["필름 만들기"].firstMatch
        XCTAssertTrue(startExport.waitForExistence(timeout: 8))
        startExport.tap()

        // 합성이 끝나면 홈 버튼이 먼저 나타난다. 앱 보관이 끝나야 탭할 수 있다.
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let goHome = app.buttons["내 필름으로"].firstMatch
        let archived = app.staticTexts["앱에 보관했어요"].firstMatch
        let limit = app.staticTexts.matching(NSPredicate(format: "label IN %@", [
            "영상 생성은 하루에 1번만 할 수 있어요.", "영상 생성은 일주일에 3번까지만 할 수 있어요."
        ])).firstMatch
        let deadline = Date().addingTimeInterval(120)
        while Date() < deadline, !limit.exists {
            dismissPhotoPermissionAlert(springboard: springboard)
            if archived.exists && goHome.exists && goHome.isEnabled && goHome.isHittable { break }
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }
        if limit.exists {
            throw XCTSkip("export 쿼터(하루 1회) 소진 — 시뮬레이터 앱 데이터를 지우고 다시 실행")
        }
        XCTAssertTrue(archived.exists, "필름이 120초 안에 앱 보관함에 저장되지 않았다. \(app.debugDescription)")
        dismissPhotoPermissionAlert(springboard: springboard)
        XCTAssertTrue(goHome.exists && goHome.isEnabled && goHome.isHittable, "앱에 보관한 필름의 홈 이동 버튼이 비활성이다")
        goHome.tap()

        // 홈 라이브러리에 방금 만든 필름 포스터가 있어야 한다.
        let poster = app.buttons["home.latestFilm"].firstMatch
        XCTAssertTrue(poster.waitForExistence(timeout: 10), "홈 라이브러리 필름 포스터. \(app.debugDescription)")
        XCTAssertTrue(poster.label.contains(filmTitle), "방금 만든 필름이 최신 표지여야 한다")
        XCTAssertTrue(poster.label.contains("00:04"), "2.4초와 2.0초 클립의 합계")

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "home-library-cover"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// 사진 보관함 권한 시스템 알럿이 떠 있으면 허용으로 닫는다 (ko/en 시스템 언어 모두).
    private func dismissPhotoPermissionAlert(springboard: XCUIApplication) {
        let allow = springboard.alerts.buttons.matching(NSPredicate(
            format: "label IN %@", ["허용", "Allow", "모든 사진에 대한 접근 허용", "Allow Access to All Photos",
                                     "전체 접근 허용", "Allow Full Access", "사진 추가만 허용", "Allow Adding Photos Only"]
        )).firstMatch
        if allow.exists {
            allow.tap()
        }
    }
}
