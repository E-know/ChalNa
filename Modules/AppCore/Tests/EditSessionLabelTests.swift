import Foundation
import Testing
import CoreGraphics
import Models
import AppCore

struct EditSessionLabelTests {

    @Test func defaultLabelOnMiss() {
        let session = EditSession()
        let id = UUID()
        #expect(session.label(for: id) == .default)
        #expect(session.label(for: id).isVisible == false)
    }

    @Test func setAndReadLabel() {
        let session = EditSession()
        let id = UUID()
        var l = ClipLabel(text: "성산일출봉", font: .system, style: .boxed)
        l.position = CGPoint(x: 0.2, y: 0.8)
        session.setLabel(l, for: id)
        #expect(session.label(for: id) == l)
        #expect(session.label(for: id).isVisible == true)
    }

    @Test func replaceResetsLabels() {
        let session = EditSession()
        let id = UUID()
        session.setLabel(ClipLabel(text: "x"), for: id)
        session.replace(clips: [], title: "새 필름")
        #expect(session.label(for: id) == .default)
    }

    @Test func clearResetsLabels() {
        let session = EditSession()
        let id = UUID()
        session.setLabel(ClipLabel(text: "x"), for: id)
        session.clear()
        #expect(session.label(for: id) == .default)
    }
}
