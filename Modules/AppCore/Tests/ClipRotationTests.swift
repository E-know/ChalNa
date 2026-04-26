import Foundation
import Testing
import Models
import AppCore

struct ClipRotationTests {

    @Test func testNextCyclesThroughFourSteps() {
        var r: ClipRotation = .r0
        r = r.next()
        #expect(r == .r90)
        r = r.next()
        #expect(r == .r180)
        r = r.next()
        #expect(r == .r270)
        r = r.next()
        #expect(r == .r0, "4번 next() 후에는 원위치여야 한다")
    }

    @Test func testSwapsAxes() {
        #expect(ClipRotation.r0.swapsAxes == false)
        #expect(ClipRotation.r180.swapsAxes == false)
        #expect(ClipRotation.r90.swapsAxes == true)
        #expect(ClipRotation.r270.swapsAxes == true)
    }

    @Test func testEditSessionCycleRotation() {
        let session = EditSession()
        let id = UUID()
        #expect(session.rotation(for: id) == .r0, "기본값은 r0")
        session.cycleRotation(for: id)
        #expect(session.rotation(for: id) == .r90)
        session.cycleRotation(for: id)
        session.cycleRotation(for: id)
        session.cycleRotation(for: id)
        #expect(session.rotation(for: id) == .r0, "4번 cycle 후 원위치")
    }
}
