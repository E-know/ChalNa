import XCTest

/// Timeline 세로 예산 실측 검증 (devMock, 사진 권한 불필요).
///
/// 스펙 §6.5 의 예산 계산은 근사치다. 실제로 하단 EditToolbar 가 화면 안에
/// 들어오는지는 가장 작은 기기에서 확인해야만 알 수 있다.
/// **iPhone SE (3rd generation) 에서 실행해야 의미가 있다.**
final class TimelineLayoutUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testTimelineFitsOnScreen_EditToolbarVisible() throws {
        let app = XCUIApplication()
        app.launchEnvironment["CHALNA_APP_MODE"] = "devMock"
        app.launchArguments += ["-AppleLanguages", "(ko)"]
        app.launch()

        let newVlog = app.buttons["새 Vlog 만들기"].firstMatch
        XCTAssertTrue(newVlog.waitForExistence(timeout: 10), "홈의 새 Vlog 버튼")
        newVlog.tap()

        // dev fixture 2개 선택
        let firstAsset = app.buttons.matching(NSPredicate(format: "label CONTAINS '협재 바다'")).firstMatch
        XCTAssertTrue(firstAsset.waitForExistence(timeout: 10), "dev fixture: 협재 바다")
        firstAsset.tap()
        let secondAsset = app.buttons.matching(NSPredicate(format: "label CONTAINS '카페 테이블'")).firstMatch
        XCTAssertTrue(secondAsset.waitForExistence(timeout: 5), "dev fixture: 카페 테이블")
        secondAsset.tap()

        let confirm = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Timeline으로'")).firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "Timeline으로 버튼")
        confirm.tap()

        // 하단 EditToolbar 4개 항목이 모두 존재하고 화면 안에 들어와야 한다.
        let screen = app.windows.firstMatch.frame
        for label in ["조정", "라벨", "삭제", "저장"] {
            let button = app.buttons[label].firstMatch
            XCTAssertTrue(button.waitForExistence(timeout: 15), "하단 툴바 '\(label)' 버튼이 없다")
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

        // 필름스트립 셀도 접근 가능해야 한다.
        XCTAssertTrue(app.collectionViews.firstMatch.exists, "필름스트립 collection view")

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "timeline-layout"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
