import Foundation
import Testing
import Models
@testable import AppCore

struct EditSessionScalesTests {
    private func makeClip() -> Clip {
        Clip(kind: .live, capturedAt: Date(), duration: 1, preset: .jejuSea)
    }

    @Test func testTransformDefaultsToFill() {
        let s = EditSession()
        let c = makeClip()
        #expect(s.transform(for: c.id) == .fill)
    }

    @Test func testSetAndReadTransform() {
        let s = EditSession()
        let c = makeClip()
        let t = ClipTransform(scale: 2, offset: CGPoint(x: 0.1, y: -0.2))
        s.setTransform(t, for: c.id)
        #expect(s.transform(for: c.id) == t)
    }

    @Test func testResetTransform() {
        let s = EditSession()
        let c = makeClip()
        s.setTransform(ClipTransform(scale: 3), for: c.id)
        s.resetTransform(for: c.id)
        #expect(s.transform(for: c.id) == .fill)
    }

    @Test func testReplaceClearsScales() {
        let s = EditSession()
        let c = makeClip()
        s.setTransform(ClipTransform(scale: 2), for: c.id)
        s.replace(clips: [makeClip()], title: "x")
        #expect(s.transform(for: c.id) == .fill)
        #expect(s.transforms.isEmpty)
    }

    @Test func testClearClearsScales() {
        let s = EditSession()
        let c = makeClip()
        s.setTransform(ClipTransform(scale: 2), for: c.id)
        s.clear()
        #expect(s.transforms.isEmpty)
    }
}
