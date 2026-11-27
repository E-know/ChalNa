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

    @Test(arguments: [ClipKind.video, .live])
    func addsIndependentRangesFromOneSource(kind: ClipKind) async throws {
        let prior = Clip(kind: .live, capturedAt: Date(), duration: 2, preset: .field)
        var source = Clip(kind: kind, capturedAt: Date(), duration: 10, preset: .cafe,
                          thumbnailData: Data([1]), videoURL: URL(fileURLWithPath: "/source.mov"),
                          locationNote: "카페", displaySize: CGSize(width: 360, height: 640))
        source.setTrimRange(0.5...2)
        let following = Clip(kind: .live, capturedAt: Date(), duration: 1, preset: .field)
        let clips = [prior, source, following]
        let transform = ClipTransform(scale: 1.5)
        let label = ClipLabel(text: "첫 장면")
        let session = EditSession(clips: clips, rotations: [source.id: .r90],
                                  labels: [source.id: label], transforms: [source.id: transform])
        let store = TestStore(initialState: TimelineFeature.State(clips: clips, currentIndex: 1)) {
            TimelineFeature()
        } withDependencies: {
            $0.editSession = session
            $0.uuid = .incrementing
        }
        store.exhaustivity = .off

        await store.send(.trimTapped)
        await store.send(.trimAdded(3...5, thumbnail: Data([2])))
        let first = try #require(store.state.currentClip)
        #expect(store.state.playheadSeconds == 3.5)
        #expect(first.thumbnailData == Data([2]))

        await store.send(.trimTapped)
        await store.send(.trimAdded(6...9, thumbnail: Data([3])))
        let second = try #require(store.state.currentClip)
        #expect(store.state.playheadSeconds == 5.5)
        #expect(store.state.trimEditorClip == nil)
        #expect(store.state.clips == [prior, source, first, second, following])
        #expect(Set([source.id, first.id, second.id]).count == 3)
        #expect([source, first, second].map(\.trimRange) == [0.5...2, 3...5, 6...9])
        for added in [first, second] {
            #expect(added.videoURL == source.videoURL && added.sourceDuration == source.sourceDuration)
            #expect(added.kind == kind && added.capturedAt == source.capturedAt)
            #expect(added.locationNote == source.locationNote && added.displaySize == source.displaySize)
            #expect(session.rotation(for: added.id) == .r90 && session.transform(for: added.id) == transform)
            #expect(session.label(for: added.id) == .default)
        }

        await store.send(.clipTapped(index: 2))
        await store.send(.trimTapped)
        await store.send(.trimCommitted(3...4, thumbnail: nil))
        #expect(session.clips == store.state.clips)
        #expect(session.clips[1] == source && session.label(for: source.id) == label)
        #expect(session.clips[2].trimRange == 3...4 && session.clips[2].thumbnailData == first.thumbnailData)
        #expect(session.clips[3] == second)
    }
}
