import Foundation
import CoreGraphics
import Testing
import Models
import CompositionService

struct CompositionRenderSizeTests {

    /// 입력이 무엇이든 출력 캔버스는 항상 1080×1920.
    @Test func testRenderSize_AlwaysFixed1080x1920_Portrait() async {
        let clips = [Self.makeClip(displaySize: CGSize(width: 1920, height: 1080))]
        let size = await AVFoundationCompositionService.resolveRenderSize(clips: clips, rotations: [:])
        #expect(size.width == 1080, "width: \(size.width)")
        #expect(size.height == 1920, "height: \(size.height)")
    }

    @Test func testRenderSize_FixedRegardlessOfMix() async {
        let clips = [
            Self.makeClip(displaySize: CGSize(width: 1920, height: 1080)),
            Self.makeClip(displaySize: CGSize(width: 1080, height: 1920)),
            Self.makeClip(displaySize: CGSize(width: 1080, height: 1080)),
        ]
        let size = await AVFoundationCompositionService.resolveRenderSize(clips: clips, rotations: [:])
        #expect(size.width == 1080)
        #expect(size.height == 1920)
    }

    @Test func testRenderSize_FixedWhenAllMissing() async {
        let clips = [Self.makeClip(displaySize: nil)]
        let size = await AVFoundationCompositionService.resolveRenderSize(clips: clips, rotations: [:])
        #expect(size.width == 1080)
        #expect(size.height == 1920)
    }

    @Test func testRenderSize_EmptyClips_StillFixed() async {
        let size = await AVFoundationCompositionService.resolveRenderSize(clips: [], rotations: [:])
        #expect(size.width == 1080)
        #expect(size.height == 1920)
    }

    @Test func testOutputSizeConstant() {
        #expect(AVFoundationCompositionService.outputSize == CGSize(width: 1080, height: 1920))
    }

    // MARK: - Helpers
    private static func makeClip(displaySize: CGSize?) -> Clip {
        Clip(kind: .video, capturedAt: Date(), duration: 1.0, preset: .jejuSea,
             thumbnailData: nil, videoURL: nil, locationNote: nil, displaySize: displaySize)
    }
}
