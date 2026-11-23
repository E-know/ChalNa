import CoreGraphics
import Models
import Testing
@testable import TimelineFeature

struct HorizontalFramingSnapTests {
    private static let landscapeSizes = [
        CGSize(width: 1920, height: 1080),
        CGSize(width: 1600, height: 1200),
        CGSize(width: 1080, height: 1080),
    ]
    private let canvas = CGSize(width: 270, height: 480)

    @Test(arguments: landscapeSizes, [ClipRotation.r0, .r90])
    func pinchFitsBothSidesOfTheCanvas(display: CGSize, rotation: ClipRotation) throws {
        let fillRect = rect(.fill, display: display, rotation: rotation)
        let raw = ClipTransform(scale: (canvas.width - 6) / fillRect.width,
                                offset: CGPoint(x: 2 / canvas.width, y: 0.12))

        let fit = try #require(resolve(raw, display: display, rotation: rotation, isScaling: true))
        let fittedRect = rect(fit.transform, display: display, rotation: rotation)

        #expect(fit.edge == .both)
        #expect(abs(fittedRect.minX) < 0.0001)
        #expect(abs(fittedRect.maxX - canvas.width) < 0.0001)
        #expect(fit.transform.offset.y == raw.offset.y)
    }

    @Test(arguments: [HorizontalFramingSnap.Edge.leading, .trailing])
    func panSnapsOneEdgeWithoutChangingScaleOrVerticalOffset(edge: HorizontalFramingSnap.Edge) throws {
        let display = Self.landscapeSizes[0]
        let fillRect = rect(.fill, display: display)
        let scale = 160 / fillRect.width
        let shift = (canvas.width - 160) / 2 - 5
        let raw = ClipTransform(scale: scale,
                                offset: CGPoint(x: (edge == .leading ? -shift : shift) / canvas.width, y: -0.23))

        let snap = try #require(resolve(raw, display: display))
        let snappedRect = rect(snap.transform, display: display)

        #expect(snap.edge == edge)
        #expect(abs(snappedRect.minX - (edge == .leading ? 0 : canvas.width - 160)) < 0.0001)
        #expect(snap.transform.scale == raw.scale)
        #expect(snap.transform.offset.y == raw.offset.y)
    }

    @Test func aPanNearBothEdgesPreservesZoom() throws {
        let display = Self.landscapeSizes[2]
        let raw = ClipTransform(scale: (canvas.width - 8) / rect(.fill, display: display).width,
                                offset: CGPoint(x: -1 / canvas.width, y: 0))

        let snap = try #require(resolve(raw, display: display))
        #expect(snap.edge == .leading)
        #expect(snap.transform.scale == raw.scale)
    }

    @Test func retentionReleasesWhenRawDragMovesPastTheEdge() throws {
        let display = Self.landscapeSizes[1]
        let scale = 160 / rect(.fill, display: display).width
        let alignedX = (160 - canvas.width) / (2 * canvas.width)
        var raw = ClipTransform(scale: scale, offset: CGPoint(x: alignedX + 10 / canvas.width, y: 0))

        #expect(resolve(raw, display: display) == nil)
        let retained = try #require(resolve(raw, display: display, retaining: .leading))
        #expect(abs(retained.transform.offset.x - alignedX) < 0.0001)

        raw.offset.x = alignedX + 13 / canvas.width
        #expect(resolve(raw, display: display, retaining: .leading) == nil)
    }

    private func rect(_ transform: ClipTransform, display: CGSize, rotation: ClipRotation = .r0) -> CGRect {
        ClipFraming.resolvedRect(display: display, rotation: rotation, render: canvas, transform: transform)
    }

    private func resolve(
        _ raw: ClipTransform, display: CGSize, rotation: ClipRotation = .r0,
        isScaling: Bool = false, retaining edge: HorizontalFramingSnap.Edge? = nil
    ) -> HorizontalFramingSnap? {
        HorizontalFramingSnap.resolve(
            raw, rect: rect(raw, display: display, rotation: rotation), canvasWidth: canvas.width,
            isScaling: isScaling, retaining: edge
        )
    }
}
