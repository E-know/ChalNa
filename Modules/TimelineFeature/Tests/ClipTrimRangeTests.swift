import Foundation
import Models
import Testing

struct ClipTrimRangeTests {
    private func clip(kind: ClipKind = .video, duration: Double? = 10, file: Bool = true) -> Clip {
        Clip(kind: kind, capturedAt: Date(), duration: duration, preset: .cafe,
             videoURL: file ? URL(fileURLWithPath: "/video.mov") : nil)
    }

    @Test func endpointsKeepTheOppositeHandleAndCanRestoreOriginalDuration() {
        var clip = clip()
        #expect(clip.canTrim)
        #expect(clip.trimRange == 0...10)
        clip.setTrimStart(2)
        clip.setTrimEnd(7.5)
        #expect(clip.duration == 5.5)
        #expect(clip.sourceDuration == 10)
        clip.setTrimStart(11)
        #expect(clip.trimRange == 7...7.5)
        clip.setTrimStart(-1)
        clip.setTrimEnd(-4)
        #expect(clip.trimRange == 0...0.5)
        clip.setTrimEnd(12)
        #expect(clip.trimRange == 0...10)
    }

    @Test func shortVideosKeepTheirEntirePlayableRange() {
        var clip = clip(duration: 0.32)
        #expect(clip.canTrim)
        clip.setTrimStart(0.1)
        clip.setTrimEnd(0.2)
        clip.setTrimRange(0.1...0.2)
        #expect(clip.trimRange == 0...0.32)
    }

    @Test func unsupportedClipsKeepTheirOriginalRange() {
        for var clip in [clip(kind: .live), clip(file: false), clip(duration: .nan), clip(duration: 0)] {
            let original = clip
            #expect(!clip.canTrim)
            clip.setTrimRange(2...7.5)
            clip.setTrimStart(1)
            clip.setTrimEnd(3)
            #expect(clip == original)
        }
    }

    @Test func missingDurationKeepsPlaybackFallbackAndDisablesTrimming() {
        var clip = clip(duration: nil)
        #expect(clip.videoURL != nil)
        #expect(!clip.canTrim)
        #expect(clip.sourceDuration == 0)
        clip.setTrimRange(1...2)
        #expect(clip.duration == 3)
        #expect(clip.trimRange == 0...3)
    }
}
