import Testing
import CoreGraphics
import Models
import CompositionService

struct LabelStackTests {
    @Test func stackedOrigins_centerZone_timeAboveDate() {
        let render = CGSize(width: 1000, height: 2000)
        let timeSize = CGSize(width: 300, height: 200)
        let dateSize = CGSize(width: 120, height: 40)
        let pad = CGSize(width: 40, height: 80)
        let gap: CGFloat = 24

        let r = LabelLayout.stackedOrigins(
            position: .center, timeSize: timeSize, dateSize: dateSize,
            gap: gap, renderSize: render, padding: pad
        )
        // group W=300, H=200+24+40=264; centered origin: x=(1000-300)/2=350, y=(2000-264)/2=868
        // date (bottom): x=350+(300-120)/2=440, y=868 ; time (top): x=350, y=868+40+24=932
        #expect(r.date == CGPoint(x: 440, y: 868))
        #expect(r.time == CGPoint(x: 350, y: 932))
        #expect(r.time.y > r.date.y)   // 시각이 위 (CoreAnimation y-up)
    }

    @Test func stackedOrigins_bottomLeft_clampedAndStacked() {
        let render = CGSize(width: 1000, height: 2000)
        let timeSize = CGSize(width: 300, height: 200)
        let dateSize = CGSize(width: 120, height: 40)
        let pad = CGSize(width: 40, height: 80)
        let gap: CGFloat = 24

        let r = LabelLayout.stackedOrigins(
            position: .bottomLeft, timeSize: timeSize, dateSize: dateSize,
            gap: gap, renderSize: render, padding: pad
        )
        // group W=300,H=264; bottomLeft → groupOrigin x=pad.w=40, y=pad.h=80
        // date(bottom): x=40+(300-120)/2=130, y=80 ; time(top): x=40, y=80+40+24=144
        #expect(r.date == CGPoint(x: 130, y: 80))
        #expect(r.time == CGPoint(x: 40, y: 144))
        #expect(r.time.y > r.date.y)
    }
}
