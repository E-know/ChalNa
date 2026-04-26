import Foundation
import Testing
import Models
import CompositionService
import TimelineFeature

struct TimelinePlaybackTests {

    /// Test A: Verify that currentIndex auto-advances during simulated playback
    @Test func testAdvancePlayheadSimulated_UpdatesCurrentIndex() async throws {
        let model = TimelineModel(
            title: "Test Film",
            clips: SampleData.jejuTimeline,
            currentIndex: 0,
            state: .idle
        )

        #expect(model.clips.count == 8)
        #expect(model.currentIndex == 0, "Should start at clip 0")
        #expect(model.playheadSeconds == 0, "Should start at 0 seconds")

        model.togglePlay()
        #expect(model.isPlaying, "Model should be in playing state")

        let advanceTask = Task {
            await model.advancePlayheadSimulated()
        }

        try? await Task.sleep(nanoseconds: UInt64(3.5 * 1_000_000_000))

        #expect(model.currentIndex == 1, "Should advance to clip 1 after ~3 seconds")
        #expect(model.playheadSeconds > 3.0, "Playhead should be past 3 seconds")

        try? await Task.sleep(nanoseconds: UInt64(3.5 * 1_000_000_000))

        #expect(model.currentIndex == 2, "Should advance to clip 2 after ~6 seconds")
        #expect(model.playheadSeconds > 6.0, "Playhead should be past 6 seconds")

        model.togglePlay()
        try? await Task.sleep(nanoseconds: 500_000_000)
        advanceTask.cancel()
    }

    /// Test B: Verify export service responds appropriately when no video clips are available
    @Test func testExportFlow_HandlesNoVideoError() async throws {
        let clips = SampleData.jejuTimeline
        #expect(!clips.isEmpty, "Should have sample clips")
        #expect(clips.allSatisfy { $0.videoURL == nil }, "Sample clips should have no videoURL")

        let service = AVFoundationCompositionService()
        var finalError: String? = nil
        var progressEvents: Int = 0

        for await event in service.export(clips: clips) {
            switch event {
            case .progress:
                progressEvents += 1
            case .completed:
                break
            case .failed(let msg):
                finalError = msg
            }
        }

        #expect(finalError != nil, "Should report error when no video is available")
        #expect(finalError?.contains("영상") ?? false || finalError?.contains("video") ?? false,
                "Error message should mention missing video")
        #expect(progressEvents == 0, "Should not produce progress events when no video available")
    }
}
