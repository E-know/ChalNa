import AppCore
import ComposableArchitecture
import Foundation
import Models
import Testing
@testable import TimelineFeature

@MainActor
struct TimelineTrimTests {
    @Test func trimFollowsClipAndPreservesOtherEdits() async {
        let prior = Clip(kind: .live, capturedAt: Date(), duration: 2, preset: .field)
        let selected = Clip(kind: .video, capturedAt: Date(), duration: 10, preset: .cafe,
                            videoURL: URL(fileURLWithPath: "/clip.mov"))
        let clips = [prior, selected]
        let session = EditSession(clips: clips, rotations: [selected.id: .r90])
        let store = TestStore(initialState: TimelineFeature.State(
            clips: clips, currentIndex: 1, playbackState: .playing, playheadSeconds: 5
        )) { TimelineFeature() } withDependencies: { $0.editSession = session }
        store.exhaustivity = .off

        await store.send(.trimTapped)
        #expect(!store.state.isPlaying)
        #expect(store.state.trimEditorClip == selected)
        await store.send(.trimDismissed)
        #expect(session.clips == clips && store.state.playheadSeconds == 5)

        await store.send(.trimTapped)
        let thumbnail = Data([1, 2, 3])
        await store.send(.trimCommitted(2...7.5, thumbnail: thumbnail))
        #expect(store.state.totalDuration == 7.5)
        #expect(store.state.playheadSeconds == 2)
        #expect(store.state.currentClip?.sourceDuration == 10)
        #expect(store.state.currentClip?.thumbnailData == thumbnail)
        #expect(session.clips == store.state.clips && session.clips[0] == prior)
        #expect(session.rotation(for: selected.id) == .r90)

        await store.send(.clipMoved(id: selected.id, toIndex: 0))
        await store.send(.trimTapped)
        #expect(store.state.trimEditorClip?.trimRange == 2...7.5)
        await store.send(.trimDismissed)
        await store.send(.clipTapped(index: 1))
        await store.send(.trimTapped)
        #expect(store.state.trimEditorClip == nil)
    }

    @Test func livePhotoTrimPersistsInEditSession() async {
        let pairedVideo = URL(fileURLWithPath: "/paired.mov")
        let livePhoto = Clip(kind: .live, capturedAt: Date(), duration: 3, preset: .field, videoURL: pairedVideo)
        let session = EditSession(clips: [livePhoto])
        let store = TestStore(initialState: TimelineFeature.State(clips: [livePhoto])) {
            TimelineFeature()
        } withDependencies: { $0.editSession = session }
        store.exhaustivity = .off

        await store.send(.trimTapped)
        #expect(store.state.trimEditorClip == livePhoto)
        await store.send(.trimCommitted(0.5...2, thumbnail: nil))

        #expect(store.state.totalDuration == 1.5)
        #expect(session.clips == store.state.clips)
        #expect(session.clips.first?.trimRange == 0.5...2)
        #expect(session.clips.first?.kind == .live)
        #expect(session.clips.first?.videoURL == pairedVideo)

        await store.send(.trimTapped)
        #expect(store.state.trimEditorClip?.trimRange == 0.5...2)
    }
}
