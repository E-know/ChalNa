import Foundation
import CoreGraphics
import Testing
import Models
import CompositionService

struct CompositionRenderSizeTests {

    /// 면적 최대 클립이 캔버스로 선택되는지 — 720×1280, 1080×1920, 1920×1080 중 1080×1920이 면적 최대.
    @Test func testRenderSize_PicksLargestArea_PortraitDominant() async {
        let clips = [
            Self.makeClip(displaySize: CGSize(width: 720, height: 1280)),
            Self.makeClip(displaySize: CGSize(width: 1080, height: 1920)),
            Self.makeClip(displaySize: CGSize(width: 1920, height: 1080))
        ]
        let size = await AVFoundationCompositionService.resolveRenderSize(clips: clips, rotations: [:])
        #expect(abs(size.width - 1080) < 0.001, "캔버스 width: \(size.width)")
        #expect(abs(size.height - 1920) < 0.001, "캔버스 height: \(size.height)")
    }

    /// 면적 동률은 첫 등장 클립이 우선 — 1920×1080과 1080×1920 모두 면적 2,073,600.
    @Test func testRenderSize_TieBreaksByFirstAppearance() async {
        let clips = [
            Self.makeClip(displaySize: CGSize(width: 1920, height: 1080)),
            Self.makeClip(displaySize: CGSize(width: 1080, height: 1920))
        ]
        let size = await AVFoundationCompositionService.resolveRenderSize(clips: clips, rotations: [:])
        #expect(abs(size.width - 1920) < 0.001, "첫 등장(가로) 우선이어야 함: width=\(size.width)")
        #expect(abs(size.height - 1080) < 0.001, "첫 등장(가로) 우선이어야 함: height=\(size.height)")
    }

    /// 사용자 회전을 effectiveSize에 먼저 적용한 뒤 면적 비교 — 1920×1080 + r90 → 1080×1920이 캔버스로.
    @Test func testRenderSize_AppliesUserRotation_BeforeAreaCompare() async {
        let landscape = Self.makeClip(displaySize: CGSize(width: 1920, height: 1080))
        let small = Self.makeClip(displaySize: CGSize(width: 720, height: 1280))
        let rotations: [Clip.ID: ClipRotation] = [landscape.id: .r90]
        let size = await AVFoundationCompositionService.resolveRenderSize(
            clips: [landscape, small],
            rotations: rotations
        )
        #expect(abs(size.width - 1080) < 0.001, "r90 적용 후 width: \(size.width)")
        #expect(abs(size.height - 1920) < 0.001, "r90 적용 후 height: \(size.height)")
    }

    /// 모든 클립의 displaySize/videoURL이 nil이면 fallback 1080×1920.
    @Test func testRenderSize_FallbackWhenAllMissing() async {
        let clips = [
            Self.makeClip(displaySize: nil),
            Self.makeClip(displaySize: nil)
        ]
        let size = await AVFoundationCompositionService.resolveRenderSize(clips: clips, rotations: [:])
        #expect(abs(size.width - 1080) < 0.001, "fallback width: \(size.width)")
        #expect(abs(size.height - 1920) < 0.001, "fallback height: \(size.height)")
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
