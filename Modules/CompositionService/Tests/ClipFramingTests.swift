import Foundation
import CoreGraphics
import Testing
import Models

struct ClipFramingTests {
    let render = CGSize(width: 1080, height: 1920)

    // MARK: - fillScale (배치 기준 배율)

    /// 가로 1920×1080 → 9:16 캔버스: fillScale = max(1080/1920, 1920/1080) = 1.77778(상하 기준).
    @Test func testFillScale_Landscape() {
        let s = ClipFraming.fillScale(display: CGSize(width: 1920, height: 1080), rotation: .r0, render: render)
        #expect(abs(s - 1920.0 / 1080.0) < 0.0001, "\(s)")
    }

    /// 같은 비율 세로 720×1280 → fillScale = 1.5 (fit 과 동일 — 딱 맞음).
    @Test func testFillScale_Portrait_SameAspect() {
        let s = ClipFraming.fillScale(display: CGSize(width: 720, height: 1280), rotation: .r0, render: render)
        #expect(abs(s - 1.5) < 0.0001, "\(s)")
    }

    /// r90 회전 시 축 swap 후 fill. 1920×1080 + r90 → oriented 1080×1920 → fillScale 1.0.
    @Test func testFillScale_AppliesRotation() {
        let s = ClipFraming.fillScale(display: CGSize(width: 1920, height: 1080), rotation: .r90, render: render)
        #expect(abs(s - 1.0) < 0.0001, "\(s)")
    }

    // MARK: - resolvedRect (fill 센터 크롭 기준)

    /// .fill 변환의 resolvedRect 는 캔버스를 덮는 센터 크롭 사각형.
    /// 가로 1920×1080 → 3413.33×1920, origin.x = -1166.67(좌우 크롭), origin.y = 0.
    @Test func testResolvedRect_Fill_Landscape_CenterCropped() {
        let r = ClipFraming.resolvedRect(display: CGSize(width: 1920, height: 1080), rotation: .r0, render: render, transform: .fill)
        #expect(abs(r.width - 3413.33) < 0.5, "w \(r.width)")
        #expect(abs(r.height - 1920) < 0.5, "h \(r.height)")
        #expect(abs(r.minX - (-1166.67)) < 0.5, "x \(r.minX)")
        #expect(abs(r.minY - 0) < 0.5, "y \(r.minY)")
    }

    /// scale=2 → 사이즈 2배, 가운데 유지.
    @Test func testResolvedRect_Scale2_GrowsCentered() {
        let r = ClipFraming.resolvedRect(display: CGSize(width: 1080, height: 1920), rotation: .r0, render: render,
                                         transform: ClipTransform(scale: 2, offset: .zero))
        #expect(abs(r.width - 2160) < 0.5, "w \(r.width)")
        #expect(abs(r.height - 3840) < 0.5, "h \(r.height)")
        #expect(abs(r.midX - 540) < 0.5, "midX \(r.midX)")
        #expect(abs(r.midY - 960) < 0.5, "midY \(r.midY)")
    }

    /// resolvedRect 의 비제로 offset 경로 검증. scale=2 portrait + offset.x=0.5(=maxFrac) → 중심 +540px.
    @Test func testResolvedRect_Scale2_WithOffset_ShiftsCenter() {
        let r = ClipFraming.resolvedRect(display: CGSize(width: 1080, height: 1920), rotation: .r0, render: render,
                                         transform: ClipTransform(scale: 2, offset: CGPoint(x: 0.5, y: 0)))
        #expect(abs(r.width - 2160) < 0.5, "w \(r.width)")
        #expect(abs(r.midX - 1080) < 0.5, "midX \(r.midX)")
        #expect(abs(r.midY - 960) < 0.5, "midY \(r.midY)")
    }

    /// resolvedRect 의 회전(orientedSize) 경로. 가로 1920×1080 + r90 → 1080×1920 정확히 채움.
    @Test func testResolvedRect_R90_Landscape_FillsCanvas() {
        let r = ClipFraming.resolvedRect(display: CGSize(width: 1920, height: 1080), rotation: .r90, render: render, transform: .fill)
        #expect(abs(r.width - 1080) < 0.5, "w \(r.width)")
        #expect(abs(r.height - 1920) < 0.5, "h \(r.height)")
        #expect(abs(r.minX - 0) < 0.5, "x \(r.minX)")
        #expect(abs(r.minY - 0) < 0.5, "y \(r.minY)")
    }

    // MARK: - maxOffsetFraction / clampedOffset

    /// 같은 비율 클립 scale 1(딱 맞음): 이동 여지 0 — offset 은 양축 0으로 clamp.
    @Test func testClampedOffset_ExactCover_LocksToCenter() {
        let o = ClipFraming.clampedOffset(CGPoint(x: 0.5, y: 0.5),
                                          display: CGSize(width: 1080, height: 1920), rotation: .r0,
                                          render: render, scale: 1.0)
        #expect(abs(o.x) < 0.0001, "x \(o.x)")
        #expect(abs(o.y) < 0.0001, "y \(o.y)")
    }

    /// 가로 클립 scale 1: 좌우로만 이동 가능. maxFracX = (3413.33-1080)/2/1080 = 1.08025, maxFracY = 0.
    @Test func testMaxOffsetFraction_Landscape_HorizontalOnly() {
        let limit = ClipFraming.maxOffsetFraction(
            display: CGSize(width: 1920, height: 1080), rotation: .r0, render: render, scale: 1.0
        )
        #expect(abs(limit.x - 1.08025) < 0.001, "x \(limit.x)")
        #expect(abs(limit.y) < 0.0001, "y \(limit.y)")
    }

    /// 가로 클립 scale 1 + 과도한 offset → x 는 한계로, y 는 0 으로 clamp.
    @Test func testClampedOffset_Landscape_ClampsToCropLimit() {
        let o = ClipFraming.clampedOffset(CGPoint(x: 2.0, y: -0.5),
                                          display: CGSize(width: 1920, height: 1080), rotation: .r0,
                                          render: render, scale: 1.0)
        #expect(abs(o.x - 1.08025) < 0.001, "x \(o.x)")
        #expect(abs(o.y) < 0.0001, "y \(o.y)")
    }

    /// 세로 클립 scale=2: maxFrac = 0.5 양축. 과도한 offset 은 [-0.5,0.5]로 clamp.
    @Test func testClampedOffset_Zoomed_ClampsToCoverEdge() {
        let o = ClipFraming.clampedOffset(CGPoint(x: 1.0, y: -1.0),
                                          display: CGSize(width: 1080, height: 1920), rotation: .r0,
                                          render: render, scale: 2.0)
        #expect(abs(o.x - 0.5) < 0.0001, "x \(o.x)")
        #expect(abs(o.y - (-0.5)) < 0.0001, "y \(o.y)")
    }

    /// scale<1(캔버스를 못 덮음): 여백이 드러나는 이동은 금지 — offset 양축 0 고정.
    /// (UI/export 는 scale 을 1 미만으로 커밋하지 않지만, 기하는 방어적으로 0 을 보장)
    @Test func testClampedOffset_BelowCover_LocksToCenter() {
        let o = ClipFraming.clampedOffset(CGPoint(x: 1.0, y: -1.0),
                                          display: CGSize(width: 1080, height: 1920), rotation: .r0,
                                          render: render, scale: 0.5)
        #expect(abs(o.x) < 0.0001, "x \(o.x)")
        #expect(abs(o.y) < 0.0001, "y \(o.y)")
    }

    // MARK: - 회전 + offset 조합 (회전이 이동 한계를 바꾸는 경로)

    /// 세로 1080×1920 + r90 → oriented 1920×1080 → fillScale 1.77778, 가로로만 이동 가능.
    /// maxFrac = ((1920×1.77778−1080)/2/1080, 0) = (1.08025, 0).
    @Test func testMaxOffsetFraction_R90_Portrait_BecomesHorizontal() {
        let limit = ClipFraming.maxOffsetFraction(
            display: CGSize(width: 1080, height: 1920), rotation: .r90, render: render, scale: 1.0
        )
        #expect(abs(limit.x - 1.08025) < 0.001, "x \(limit.x)")
        #expect(abs(limit.y) < 0.0001, "y \(limit.y)")
    }

    /// 가로 1920×1080 + r90 → oriented 1080×1920(딱 맞음) → 이동 한계 0.
    /// r0 에서 유효했던 offset(1.08)이 r90 에서는 (0,0)으로 clamp 되어야 한다
    /// — 회전 후 stale offset 재클램프의 기하 가드.
    @Test func testClampedOffset_R90_Landscape_InvalidatesStaleOffset() {
        let o = ClipFraming.clampedOffset(CGPoint(x: 1.08025, y: 0),
                                          display: CGSize(width: 1920, height: 1080), rotation: .r90,
                                          render: render, scale: 1.0)
        #expect(abs(o.x) < 0.0001, "x \(o.x)")
        #expect(abs(o.y) < 0.0001, "y \(o.y)")
    }

    /// r90 + 비제로 offset 의 resolvedRect: 세로 클립을 r90 돌리면 가로가 되어
    /// offset.x=maxFrac 에서 rect 좌측 끝이 캔버스 좌측(0)에 닿는다.
    @Test func testResolvedRect_R90_WithOffset_ShiftsWithinLimit() {
        let r = ClipFraming.resolvedRect(
            display: CGSize(width: 1080, height: 1920), rotation: .r90, render: render,
            transform: ClipTransform(scale: 1, offset: CGPoint(x: 1.08025, y: 0))
        )
        #expect(abs(r.width - 3413.33) < 0.5, "w \(r.width)")
        #expect(abs(r.minX - 0) < 0.5, "minX \(r.minX)")
        #expect(abs(r.minY - 0) < 0.5, "minY \(r.minY)")
    }
}
