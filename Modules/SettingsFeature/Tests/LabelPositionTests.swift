import Testing
import CoreGraphics
import Models

struct LabelPositionTests {
    let render = CGSize(width: 1000, height: 2000)
    let text = CGSize(width: 100, height: 40)
    let pad = CGSize(width: 20, height: 20)

    @Test func centerIsCentered() {
        let o = LabelPosition.center.origin(renderSize: render, textSize: text, padding: pad)
        #expect(o.x == 450)   // (1000-100)/2
        #expect(o.y == 980)   // (2000-40)/2
    }

    @Test func topLeftRespectsPadding() {
        let o = LabelPosition.topLeft.origin(renderSize: render, textSize: text, padding: pad)
        #expect(o.x == 20)     // minX
        #expect(o.y == 1940)   // maxY = 2000-20-40 (CoreAnimation: top = 큰 y)
    }

    @Test func bottomRightRespectsPadding() {
        let o = LabelPosition.bottomRight.origin(renderSize: render, textSize: text, padding: pad)
        #expect(o.x == 880)    // 1000-20-100
        #expect(o.y == 20)     // minY (bottom)
    }

    @Test func bottomCenterMatchesLegacyDefault() {
        let o = LabelPosition.bottomCenter.origin(renderSize: render, textSize: text, padding: pad)
        #expect(o.x == 450)
        #expect(o.y == 20)
    }

    @Test func nineCasesWithKoreanNames() {
        #expect(LabelPosition.allCases.count == 9)
        #expect(LabelPosition.allCases.allSatisfy { !$0.koreanName.isEmpty })
    }

    @Test func defaultSettingsMatchCurrentExport() {
        let s = LabelSettings.default
        #expect(s.timeEnabled)
        #expect(s.dateEnabled)
        #expect(s.timePosition == .center)
        #expect(s.datePosition == .bottomCenter)
    }

    @Test func defaultOpacities() {
        #expect(LabelSettings.default.timeOpacity == 0.5)
        #expect(LabelSettings.default.dateOpacity == 1.0)
    }
}
