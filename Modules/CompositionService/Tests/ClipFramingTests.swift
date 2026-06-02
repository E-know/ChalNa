import Foundation
import CoreGraphics
import Testing
import Models

struct ClipFramingTests {
    let render = CGSize(width: 1080, height: 1920)

    /// 가로 1920×1080 → 9:16 캔버스: fitScale = 1080/1920 = 0.5625.
    @Test func testFitScale_Landscape() {
        let s = ClipFraming.fitScale(display: CGSize(width: 1920, height: 1080), rotation: .r0, render: render)
        #expect(abs(s - 0.5625) < 0.0001, "\(s)")
    }

    /// 세로 720×1280 → 9:16 캔버스: fitScale = min(1080/720, 1920/1280)=min(1.5,1.5)=1.5.
    @Test func testFitScale_Portrait() {
        let s = ClipFraming.fitScale(display: CGSize(width: 720, height: 1280), rotation: .r0, render: render)
        #expect(abs(s - 1.5) < 0.0001, "\(s)")
    }

    /// r90 회전 시 축 swap 후 fit. 1920×1080 + r90 → oriented 1080×1920 → fitScale 1.0.
    @Test func testFitScale_AppliesRotation() {
        let s = ClipFraming.fitScale(display: CGSize(width: 1920, height: 1080), rotation: .r90, render: render)
        #expect(abs(s - 1.0) < 0.0001, "\(s)")
    }

    /// .fit 변환의 resolvedRect 는 가운데 정렬 fit 사각형. 가로 1920×1080 → 1080×607.5, origin.y=656.25.
    @Test func testResolvedRect_Fit_Landscape_Centered() {
        let r = ClipFraming.resolvedRect(display: CGSize(width: 1920, height: 1080), rotation: .r0, render: render, transform: .fit)
        #expect(abs(r.width - 1080) < 0.5, "w \(r.width)")
        #expect(abs(r.height - 607.5) < 0.5, "h \(r.height)")
        #expect(abs(r.minX - 0) < 0.5, "x \(r.minX)")
        #expect(abs(r.minY - 656.25) < 0.5, "y \(r.minY)")
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

    /// fit 일 때 offset 은 양축 0으로 clamp.
    @Test func testClampedOffset_Fit_LocksToCenter() {
        let o = ClipFraming.clampedOffset(CGPoint(x: 0.5, y: 0.5),
                                          display: CGSize(width: 1080, height: 1920), rotation: .r0,
                                          render: render, scale: 1.0)
        #expect(abs(o.x) < 0.0001, "x \(o.x)")
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
}
