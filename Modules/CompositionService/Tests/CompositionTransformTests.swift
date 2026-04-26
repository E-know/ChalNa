import Foundation
import CoreGraphics
import Testing
import Models
import CompositionService

struct CompositionTransformTests {

    /// r0: 가로 1920×1080 클립이 1080×1080 renderSize에 가운데 정렬되어야 한다.
    @Test func testTransform_R0_GivesCenteredIdentity() {
        let natural = CGSize(width: 1920, height: 1080)
        let render = CGSize(width: 1080, height: 1080)
        let t = AVFoundationCompositionService.transform(
            naturalSize: natural,
            preferredTransform: .identity,
            rotation: .r0,
            renderSize: render
        )
        let origin = CGPoint(x: 0, y: 0).applying(t)
        #expect(abs(origin.x - (render.width - natural.width) / 2) < 0.001)
        #expect(abs(origin.y - (render.height - natural.height) / 2) < 0.001)
    }

    /// r90: 가로 1920×1080 클립이 r90 회전 후 1080×1920로 swap되고
    /// renderSize 1080×1920에 가운데 정렬되어야 한다 (정확히 꽉 참).
    @Test func testTransform_R90_FillsRotatedCanvas() {
        let natural = CGSize(width: 1920, height: 1080)
        let render = CGSize(width: 1080, height: 1920)
        let t = AVFoundationCompositionService.transform(
            naturalSize: natural,
            preferredTransform: .identity,
            rotation: .r90,
            renderSize: render
        )
        let renderRect = CGRect(origin: .zero, size: render)
        let corners = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: natural.width, y: 0),
            CGPoint(x: 0, y: natural.height),
            CGPoint(x: natural.width, y: natural.height)
        ]
        for c in corners {
            let mapped = c.applying(t)
            #expect(mapped.x >= renderRect.minX - 0.5 && mapped.x <= renderRect.maxX + 0.5,
                    "r90 매핑된 모서리가 render width 안에 있어야 함: \(mapped.x)")
            #expect(mapped.y >= renderRect.minY - 0.5 && mapped.y <= renderRect.maxY + 0.5,
                    "r90 매핑된 모서리가 render height 안에 있어야 함: \(mapped.y)")
        }
    }

    /// r180: 사이즈 swap 없이 가운데 정렬, 180° 뒤집힘.
    @Test func testTransform_R180_KeepsAxesButFlips() {
        let natural = CGSize(width: 1080, height: 1080)
        let render = CGSize(width: 1080, height: 1080)
        let t = AVFoundationCompositionService.transform(
            naturalSize: natural,
            preferredTransform: .identity,
            rotation: .r180,
            renderSize: render
        )
        let mapped = CGPoint(x: 0, y: 0).applying(t)
        #expect(abs(mapped.x - render.width) < 0.5)
        #expect(abs(mapped.y - render.height) < 0.5)
    }
}
