import Foundation
import Testing
import ComposableArchitecture
import Models
import CompositionService
@testable import TimelineFeature

@MainActor
struct TimelinePlaybackTests {

    @Test func testSelectClip_UpdatesCurrentIndexAndPlayhead() async {
        let clips = SampleData.jejuTimeline
        let store = TestStore(
            initialState: TimelineFeature.State(title: "Test Film", clips: clips)
        ) {
            TimelineFeature()
        }
        store.exhaustivity = .off

        await store.send(.clipTapped(index: 3))

        let expectedPlayhead = clips.prefix(3).reduce(0) { $0 + $1.duration }
        #expect(store.state.currentIndex == 3, "Selected clip index should become currentIndex")
        #expect(store.state.currentClip?.id == clips[3].id, "Current clip should match the selected clip")
        #expect(store.state.playheadSeconds == expectedPlayhead, "Playhead should jump to the selected clip start")
    }

    @Test func testCurrentClipEnded_AdvancesCurrentIndex() async {
        let clips = SampleData.jejuTimeline
        let store = TestStore(
            initialState: TimelineFeature.State(title: "Test Film", clips: clips)
        ) {
            TimelineFeature()
        }
        store.exhaustivity = .off

        #expect(store.state.clips.count == 8)
        #expect(store.state.currentIndex == 0, "Should start at clip 0")
        #expect(store.state.playheadSeconds == 0, "Should start at 0 seconds")

        await store.send(.togglePlay)
        #expect(store.state.isPlaying, "Timeline should be in playing state")

        await store.send(.currentClipEnded)

        #expect(store.state.currentIndex == 1, "Should advance to clip 1 when current clip ends")
        #expect(store.state.playheadSeconds == clips[0].duration, "Playhead should jump to the next clip start")

        await store.send(.currentClipEnded)

        let secondClipStart = clips.prefix(2).reduce(0) { $0 + $1.duration }
        #expect(store.state.currentIndex == 2, "Should advance to clip 2 after another clip end")
        #expect(store.state.playheadSeconds == secondClipStart, "Playhead should track cumulative clip starts")

        await store.send(.togglePlay)
        #expect(!store.state.isPlaying, "Timeline should return to idle")
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
