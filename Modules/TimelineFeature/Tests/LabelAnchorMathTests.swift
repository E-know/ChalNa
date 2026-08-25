import CoreGraphics
import Foundation
import Testing
@testable import TimelineFeature

/// 좌상단 코너 ↔ 중심 변환의 무손실 왕복과, 에디터의 **중심 고정** 정책을 검증한다.
/// 측정(UIFont)은 환경 의존이라 제외하고, paddedSize 를 직접 주입해 순수 기하만 본다.
struct LabelAnchorMathTests {

    private let box = CGSize(width: 300, height: 533)   // 9:16 표시 박스 예시

    @Test func testTopLeftCenterRoundTrip() {
        let center = CGPoint(x: 0.4, y: 0.6)
        let padded = CGSize(width: 120, height: 48)

        let corner = LabelAnchorMath.topLeft(center: center, in: box, paddedSize: padded)
        let back = LabelAnchorMath.center(topLeft: corner, in: box, paddedSize: padded)

        #expect(abs(back.x - center.x) < 1e-9, "center → corner → center 왕복 시 x 보존")
        #expect(abs(back.y - center.y) < 1e-9, "center → corner → center 왕복 시 y 보존")
    }

    /// **순수 변환의 성질**이며 에디터 정책이 아니다 — 에디터는 중심을 단일 출처로 쓰므로
    /// 실제로는 코너가 아니라 중심이 고정된다(아래 `testSizeGrows_CenterFixed_ExpandsEvenly`).
    /// 이 테스트는 "같은 코너에서 폭만 다르게 환산하면" 중심이 어떻게 움직이는지를 잠근다.
    @Test func testTextGrows_LeadingFixed_TrailingExpands() {
        // 같은 좌상단 코너를 유지한 채 폭만 커지면, 중심 x 는 우측으로 이동(= trailing 확장)한다.
        let corner = LabelAnchorMath.topLeft(center: CGPoint(x: 0.3, y: 0.5), in: box, paddedSize: CGSize(width: 100, height: 48))

        let narrow = LabelAnchorMath.center(topLeft: corner, in: box, paddedSize: CGSize(width: 100, height: 48))
        let wide = LabelAnchorMath.center(topLeft: corner, in: box, paddedSize: CGSize(width: 180, height: 48))

        // 같은 코너로부터 다시 코너를 역산하면 동일(leading 고정).
        let narrowCorner = LabelAnchorMath.topLeft(center: narrow, in: box, paddedSize: CGSize(width: 100, height: 48))
        let wideCorner = LabelAnchorMath.topLeft(center: wide, in: box, paddedSize: CGSize(width: 180, height: 48))

        #expect(abs(narrowCorner.x - wideCorner.x) < 1e-9, "폭이 변해도 leading(minX) 고정")
        #expect(wide.x > narrow.x, "폭이 커지면 중심 x 가 우측으로 이동(trailing 확장)")
    }

    /// 에디터 정책: 크기(슬라이더·핀치)가 변해도 **중심이 고정**된다.
    ///
    /// 배치 단일 출처가 정규화 중심이므로, 같은 중심에서 코너를 다시 뽑으면 박스가 커진 만큼
    /// 좌·상으로도 균등하게 벌어진다 — 우·하로만 확장하던 예전(코너 고정) 규칙을 핀치 도입과
    /// 함께 중심 고정으로 통일했다.
    @Test func testSizeGrows_CenterFixed_ExpandsEvenly() {
        let center = CGPoint(x: 0.35, y: 0.35)
        let small = LabelAnchorMath.topLeft(center: center, in: box, paddedSize: CGSize(width: 90, height: 40))
        let large = LabelAnchorMath.topLeft(center: center, in: box, paddedSize: CGSize(width: 150, height: 70))

        #expect(large.x < small.x, "크기 ↑ → 좌측으로도 벌어진다(중심 고정)")
        #expect(large.y < small.y, "크기 ↑ → 위로도 벌어진다(중심 고정)")
        #expect(abs((small.x - large.x) - (150 - 90) / 2) < 1e-9, "좌우 균등 확장")
        #expect(abs((small.y - large.y) - (70 - 40) / 2) < 1e-9, "상하 균등 확장")

        // 중심은 보존된다(왕복 무손실).
        let backSmall = LabelAnchorMath.center(topLeft: small, in: box, paddedSize: CGSize(width: 90, height: 40))
        let backLarge = LabelAnchorMath.center(topLeft: large, in: box, paddedSize: CGSize(width: 150, height: 70))
        #expect(abs(backSmall.x - backLarge.x) < 1e-9 && abs(backSmall.y - backLarge.y) < 1e-9,
                "크기가 달라도 중심은 같아야 한다")
    }

    @Test func testCenterClampsToUnitRange() {
        let padded = CGSize(width: 80, height: 40)
        // 박스 밖으로 한참 벗어난 코너 → 중심은 0…1 로 clamp.
        let far = CGPoint(x: 10_000, y: -10_000)
        let c = LabelAnchorMath.center(topLeft: far, in: box, paddedSize: padded)
        #expect(c.x == 1, "오른쪽 초과 시 1 로 clamp")
        #expect(c.y == 0, "위쪽 초과 시 0 으로 clamp")
    }

    @Test func testZeroBoxIsSafe() {
        let c = LabelAnchorMath.center(topLeft: CGPoint(x: 5, y: 5), in: .zero, paddedSize: CGSize(width: 10, height: 10))
        #expect(c == CGPoint(x: 0.5, y: 0.5), "0 박스에서도 안전한 기본값(0.5,0.5)")
    }
}
