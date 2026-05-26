import Foundation
import CoreGraphics
import Testing
import Models
import CompositionService

struct CompositionRenderSizeTests {

    /// 단일 가로 클립 → 그 비율 그대로 (1920×1080).
    @Test func testRenderSize_SingleLandscape_UsesItsSize() async {
        let clips = [Self.makeClip(displaySize: CGSize(width: 1920, height: 1080))]
        let size = await AVFoundationCompositionService.resolveRenderSize(clips: clips, rotations: [:])
        #expect(abs(size.width - 1920) < 0.5, "width: \(size.width)")
        #expect(abs(size.height - 1080) < 0.5, "height: \(size.height)")
    }

    /// 단일 세로 클립 → 그 비율 그대로 (1080×1920).
    @Test func testRenderSize_SinglePortrait_UsesItsSize() async {
        let clips = [Self.makeClip(displaySize: CGSize(width: 1080, height: 1920))]
        let size = await AVFoundationCompositionService.resolveRenderSize(clips: clips, rotations: [:])
        #expect(abs(size.width - 1080) < 0.5, "width: \(size.width)")
        #expect(abs(size.height - 1920) < 0.5, "height: \(size.height)")
    }

    /// 가로/세로 혼합 → maxH=1920인 세로 클립의 비율이 캔버스로.
    @Test func testRenderSize_MixedClips_PicksTallestAspect() async {
        let clips = [
            Self.makeClip(displaySize: CGSize(width: 1920, height: 1080)),
            Self.makeClip(displaySize: CGSize(width: 1080, height: 1920)),
        ]
        let size = await AVFoundationCompositionService.resolveRenderSize(clips: clips, rotations: [:])
        #expect(abs(size.width - 1080) < 0.5, "width: \(size.width)")
        #expect(abs(size.height - 1920) < 0.5, "height: \(size.height)")
    }

    /// 가로 클립 두 개 중 더 키 큰 (height 큰) 쪽이 캔버스.
    /// 1920×1080(h=1080) vs 1280×720(h=720) → 1920×1080.
    @Test func testRenderSize_AllLandscape_PicksTallerByHeight() async {
        let clips = [
            Self.makeClip(displaySize: CGSize(width: 1280, height: 720)),
            Self.makeClip(displaySize: CGSize(width: 1920, height: 1080)),
        ]
        let size = await AVFoundationCompositionService.resolveRenderSize(clips: clips, rotations: [:])
        #expect(abs(size.width - 1920) < 0.5, "width: \(size.width)")
        #expect(abs(size.height - 1080) < 0.5, "height: \(size.height)")
    }

    /// 사용자 회전이 oriented size 계산에 먼저 반영되는지.
    /// 1920×1080 + r90 → oriented 1080×1920, 다른 720×1280 보다 h가 더 큼 → 1080×1920.
    @Test func testRenderSize_AppliesUserRotation_BeforePickingTallest() async {
        let landscape = Self.makeClip(displaySize: CGSize(width: 1920, height: 1080))
        let small = Self.makeClip(displaySize: CGSize(width: 720, height: 1280))
        let rotations: [Clip.ID: ClipRotation] = [landscape.id: .r90]
        let size = await AVFoundationCompositionService.resolveRenderSize(
            clips: [landscape, small],
            rotations: rotations
        )
        #expect(abs(size.width - 1080) < 0.5, "width: \(size.width)")
        #expect(abs(size.height - 1920) < 0.5, "height: \(size.height)")
    }

    /// 사이즈 추출 모두 실패 → fallback 9:16 세로(1080×1920).
    @Test func testRenderSize_FallbackWhenAllMissing() async {
        let clips = [Self.makeClip(displaySize: nil), Self.makeClip(displaySize: nil)]
        let size = await AVFoundationCompositionService.resolveRenderSize(clips: clips, rotations: [:])
        #expect(abs(size.width - 1080) < 0.5, "fallback width: \(size.width)")
        #expect(abs(size.height - 1920) < 0.5, "fallback height: \(size.height)")
    }

    // MARK: - Helpers

    private static func makeClip(displaySize: CGSize?) -> Clip {
        Clip(
            kind: .video,
            capturedAt: Date(),
            duration: 1.0,
            preset: .jejuSea,
            thumbnailData: nil,
            videoURL: nil,
            locationNote: nil,
            displaySize: displaySize
        )
    }
}
