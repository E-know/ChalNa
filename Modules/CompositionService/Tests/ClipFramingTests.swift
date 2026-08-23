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

    // MARK: - 자유 프레이밍 (clamp 없음)

    /// 예전 이동 한계(가로 클립 scale 1 → 1.08025)를 크게 넘는 offset 도 그대로 반영된다.
    /// 1920×1080 → fillScale 1.77778 → 3413.33×1920. offset.x=2.0 → 중심이 +2160px 이동.
    /// 결과 minX = 540 - 3413.33/2 + 2160 = 993.33 (캔버스 우측 밖으로 밀려남).
    @Test func testResolvedRect_OffsetBeyondCover_MovesFreely() {
        let r = ClipFraming.resolvedRect(
            display: CGSize(width: 1920, height: 1080), rotation: .r0, render: render,
            transform: ClipTransform(scale: 1, offset: CGPoint(x: 2.0, y: 0))
        )
        #expect(abs(r.minX - 993.33) < 0.5, "minX \(r.minX)")
    }

    /// scale < 1: 전경이 캔버스보다 작아진다(여백 발생). 세로 1080×1920 × 0.5 → 540×960 중앙.
    @Test func testResolvedRect_ScaleBelowFill_SmallerThanCanvas() {
        let r = ClipFraming.resolvedRect(
            display: CGSize(width: 1080, height: 1920), rotation: .r0, render: render,
            transform: ClipTransform(scale: 0.5, offset: .zero)
        )
        #expect(abs(r.width - 540) < 0.5, "w \(r.width)")
        #expect(abs(r.height - 960) < 0.5, "h \(r.height)")
        #expect(abs(r.minX - 270) < 0.5, "minX \(r.minX)")
        #expect(abs(r.minY - 480) < 0.5, "minY \(r.minY)")
    }

    /// 축소 + 이동 조합: 작아진 전경을 캔버스 밖으로도 밀 수 있다.
    /// 540×960 을 offset(0.5, -0.5) → 중심 (540+540, 960-960) = (1080, 0) → minX 810, minY -480.
    @Test func testResolvedRect_ShrunkAndPushedOutOfCanvas() {
        let r = ClipFraming.resolvedRect(
            display: CGSize(width: 1080, height: 1920), rotation: .r0, render: render,
            transform: ClipTransform(scale: 0.5, offset: CGPoint(x: 0.5, y: -0.5))
        )
        #expect(abs(r.minX - 810) < 0.5, "minX \(r.minX)")
        #expect(abs(r.minY - (-480)) < 0.5, "minY \(r.minY)")
    }

    /// resolvedRect 는 산술 안전 가드를 경유한다 — NaN scale 은 1.0 으로 복구되어 fill 이 된다.
    @Test func testResolvedRect_NonFiniteScale_FallsBackToFill() {
        let r = ClipFraming.resolvedRect(
            display: CGSize(width: 1080, height: 1920), rotation: .r0, render: render,
            transform: ClipTransform(scale: .nan, offset: .zero)
        )
        #expect(abs(r.width - 1080) < 0.5, "w \(r.width)")
        #expect(abs(r.height - 1920) < 0.5, "h \(r.height)")
    }

    /// r90 + 비제로 offset 의 resolvedRect: 세로 클립을 r90 돌리면 가로가 되어
    /// offset.x=1.08025 에서 rect 좌측 끝이 정확히 캔버스 좌측(0)에 닿는다.
    /// (예전엔 이 값이 clamp 한계였고, 지금은 그냥 "딱 맞는 지점"이라는 의미만 남는다.)
    @Test func testResolvedRect_R90_WithOffset_ShiftsToCanvasEdge() {
        let r = ClipFraming.resolvedRect(
            display: CGSize(width: 1080, height: 1920), rotation: .r90, render: render,
            transform: ClipTransform(scale: 1, offset: CGPoint(x: 1.08025, y: 0))
        )
        #expect(abs(r.width - 3413.33) < 0.5, "w \(r.width)")
        #expect(abs(r.minX - 0) < 0.5, "minX \(r.minX)")
        #expect(abs(r.minY - 0) < 0.5, "minY \(r.minY)")
    }

    // MARK: - ClipTransform.sanitized (산술 안전 가드)

    /// 하한 미달 배율은 minScale(0.1)로 clamp — 축소 자체는 허용되지만 0 근처는 막는다.
    @Test func testSanitized_ClampsBelowMinScale() {
        let t = ClipTransform(scale: 0.05, offset: CGPoint(x: 0.3, y: -0.2)).sanitized
        #expect(abs(t.scale - ClipTransform.minScale) < 0.0001, "scale \(t.scale)")
        #expect(abs(t.offset.x - 0.3) < 0.0001, "offset 은 건드리지 않는다: \(t.offset.x)")
        #expect(abs(t.offset.y - (-0.2)) < 0.0001, "offset 은 건드리지 않는다: \(t.offset.y)")
    }

    /// 상한 초과 배율은 maxScale(10)로 clamp.
    @Test func testSanitized_ClampsAboveMaxScale() {
        let t = ClipTransform(scale: 100, offset: .zero).sanitized
        #expect(abs(t.scale - ClipTransform.maxScale) < 0.0001, "scale \(t.scale)")
    }

    /// 범위 안 값은 그대로 통과 — 0.5 는 이제 유효한 축소값이다.
    @Test func testSanitized_PassesThroughValidRange() {
        let t = ClipTransform(scale: 0.5, offset: CGPoint(x: 5, y: -5)).sanitized
        #expect(abs(t.scale - 0.5) < 0.0001, "scale \(t.scale)")
        #expect(abs(t.offset.x - 5) < 0.0001, "offset 제한 없음: \(t.offset.x)")
        #expect(abs(t.offset.y - (-5)) < 0.0001, "offset 제한 없음: \(t.offset.y)")
    }

    /// non-finite 방어: NaN scale → 1.0, NaN/Inf offset 성분 → 0.
    @Test func testSanitized_RecoversFromNonFinite() {
        // `.infinity`/`.nan` 를 한 표현식에서 중첩 초기화하면 타입 체커가 CGFloat/Double 사이에서
        // "ambiguous use of 'infinity'"를 낸다(실측) — offset 을 먼저 명시 타입으로 분리한다.
        let offset = CGPoint(x: CGFloat.infinity, y: CGFloat.nan)
        let t = ClipTransform(scale: CGFloat.nan, offset: offset).sanitized
        #expect(abs(t.scale - 1.0) < 0.0001, "scale \(t.scale)")
        #expect(t.offset.x == 0, "offset.x \(t.offset.x)")
        #expect(t.offset.y == 0, "offset.y \(t.offset.y)")
    }
}
