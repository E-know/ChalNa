import Foundation
import Testing
import CoreGraphics
import Models

struct ClipLabelTests {

    @Test func defaultIsInvisibleAndCentered() {
        let l = ClipLabel.default
        #expect(l.isVisible == false)
        #expect(l.position == CGPoint(x: 0.5, y: 0.5))
        #expect(l.sizeFraction == 0.10)
    }

    @Test func isVisibleIgnoresWhitespace() {
        #expect(ClipLabel(text: "   ").isVisible == false)
        #expect(ClipLabel(text: "\n ").isVisible == false)
        #expect(ClipLabel(text: "제주 바다").isVisible == true)
    }

    @Test func sizeFractionClamps() {
        #expect(ClipLabel(sizeFraction: 0.001).clampedSizeFraction == ClipLabel.minSizeFraction)
        #expect(ClipLabel(sizeFraction: 9).clampedSizeFraction == ClipLabel.maxSizeFraction)
        #expect(ClipLabel(sizeFraction: 0.1).clampedSizeFraction == 0.1)
        #expect(ClipLabel(sizeFraction: ClipLabel.minSizeFraction).clampedSizeFraction == ClipLabel.minSizeFraction)
        #expect(ClipLabel(sizeFraction: ClipLabel.maxSizeFraction).clampedSizeFraction == ClipLabel.maxSizeFraction)
    }
}
