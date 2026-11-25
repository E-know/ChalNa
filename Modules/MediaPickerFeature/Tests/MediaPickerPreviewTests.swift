import Foundation
import Testing
import ComposableArchitecture
import PhotosService
@testable import MediaPickerFeature

struct MediaPickerPreviewTests {

    private func makeAsset(id: String = "asset-1") -> PhotoLibraryAsset {
        PhotoLibraryAsset(id: id, kind: .livePhoto, capturedAt: nil, pixelSize: .zero)
    }

    @Test func previewRequested_setsPreviewAsset() {
        var state = MediaPickerFeature.State(source: .photoLibrary)
        let asset = makeAsset()

        _ = MediaPickerFeature().reduce(into: &state, action: .previewRequested(asset))

        #expect(state.previewAsset == asset)
    }

    @Test func previewDismissed_clearsPreviewAsset() {
        var state = MediaPickerFeature.State(source: .photoLibrary)
        state.previewAsset = makeAsset()

        _ = MediaPickerFeature().reduce(into: &state, action: .previewDismissed)

        #expect(state.previewAsset == nil)
    }
}

extension MediaPickerPreviewTests {
    @MainActor
    @Test func unavailableOriginalCanBeRemovedOrRecoveredWithoutDuplicatingIt() async throws {
        let store = Store(initialState: MediaPickerFeature.State(photoAuthorizationStatus: .limited)) { MediaPickerFeature() } withDependencies: {
            $0.uuid = .incrementing
        }
        let video = Self.movie("video")
        let failed = SelectedItem(id: "retry", media: nil)
        await store.send(.systemPickerFinished([SelectedItem(id: video.id, media: video), failed])).finish()
        #expect(store.state.selectedCount == 2)
        #expect(store.state.hasUnavailableMedia)
        #expect(!store.state.canProceed)

        let repaired = PickedMedia(id: "retry", kind: .livePhoto, thumbnailData: Data([2]),
                                   videoURL: URL(fileURLWithPath: "/tmp/retry.mov"), capturedAt: nil,
                                   duration: 3, displaySize: nil)
        await store.send(.systemPickerFinished([SelectedItem(id: repaired.id, media: repaired)])).finish()
        await store.send(.systemPickerFinished([failed])).finish()
        #expect(store.selectedAssetIDs == ["video", "retry"])
        #expect(store.state.liveCount == 1)
        #expect(store.state.canProceed)
        let removed = try #require(store.state.selectedAssets.first { $0.id == repaired.id })
        await store.send(.photoAssetTapped(removed)).finish()
        #expect(store.selectedAssetIDs == ["video"])
        #expect(store.state.canProceed)
    }
}

extension MediaPickerPreviewTests {
    @MainActor
    @Test(arguments: [PhotoLibraryAccess.limited, .authorized, .denied, .restricted])
    func permissionResultControlsSystemPicker(access: PhotoLibraryAccess) async {
        let requested = LockIsolated(0)
        let store = Store(initialState: MediaPickerFeature.State()) { MediaPickerFeature() } withDependencies: {
            $0.photoLibraryClient.authorizationStatus = { .notDetermined }
            $0.photoLibraryClient.requestAuthorization = {
                requested.withValue { $0 += 1 }
                return access
            }
        }
        #expect(store.photoAuthorizationStatus == .notDetermined)
        await store.send(.photoLauncherTapped).finish()
        let permitted = access == .limited || access == .authorized
        #expect(requested.value == 1)
        #expect(store.photoAuthorizationStatus == access)
        #expect(store.isSystemPhotoPickerPresented == permitted)
        #expect(store.isPhotoPermissionAlertPresented == !permitted)
    }

    @MainActor
    @Test func pickerLoadsInjectedItemsInSelectionOrderAndKeepsMissingOriginal() async {
        let store = Store(initialState: MediaPickerFeature.State()) { MediaPickerFeature() } withDependencies: {
            $0.uuid = .incrementing
            $0.photoLibraryClient.authorizationStatus = { .limited }
        }
        await store.send(.task).finish()
        #expect(store.photoAuthorizationStatus == .limited)
        let first = PickedMedia(id: "selected", kind: .video, thumbnailData: Data([1]),
                                videoURL: URL(fileURLWithPath: "/tmp/movie.mov"), capturedAt: nil,
                                duration: 2, displaySize: nil)
        await store.send(.systemPickerFinished([
            SelectedItem(id: "selected", media: first), SelectedItem(id: "missing", media: nil)
        ])).finish()
        #expect(store.selectedAssetIDs == ["selected", "missing"])
        #expect(store.state.hasUnavailableMedia)
        #expect(!store.isPreparingPickedMedia && store.preparingPickedMediaProgress == nil)
    }

    private struct SelectedItem: PickedMediaLoading {
        let id: String
        let media: PickedMedia?
        func load() async -> PickedMedia? { media }
    }

    @MainActor
    @Test func reportsPartialTransferBeforeAnItemFinishes() async throws {
        let store = Store(initialState: MediaPickerFeature.State()) { MediaPickerFeature() } withDependencies: {
            $0.uuid = .incrementing
        }
        let first = DeferredItem("first")
        let second = DeferredItem("second")
        defer {
            first.finish()
            second.finish()
        }
        let batch = store.send(.systemPickerFinished([first, second]))

        first.report(0.5)
        try await waitUntil { store.preparingPickedMediaProgress?.fractionCompleted == 0.25 }
        #expect(store.preparingPickedMediaProgress?.done == 0)
        second.report(0.25)
        try await waitUntil { store.preparingPickedMediaProgress?.fractionCompleted == 0.375 }
        first.finish()
        try await waitUntil { store.preparingPickedMediaProgress?.done == 1 }
        #expect(store.preparingPickedMediaProgress?.fractionCompleted == 0.625)

        second.finish()
        await batch.finish()
        #expect(store.selectedAssetIDs == ["first", "second"])
        #expect(!store.isPreparingPickedMedia && store.state.canProceed)
    }

    @MainActor
    @Test func cancellingImportKeepsCompletedClipsInSelectionOrderAndIgnoresLateCompletions() async throws {
        let store = Store(initialState: MediaPickerFeature.State()) { MediaPickerFeature() } withDependencies: {
            $0.uuid = .incrementing
        }
        let prior = Self.movie("prior")
        await store.send(.systemPickerFinished([SelectedItem(id: prior.id, media: prior)])).finish()

        let first = DeferredItem("first")
        let second = DeferredItem("second")
        let late = DeferredItem("late")
        let next = DeferredItem("next")
        defer { [first, second, late, next].forEach { $0.finish() } }

        let missing = SelectedItem(id: "missing", media: nil)
        let oldBatch = store.send(.systemPickerFinished([first, second, missing, late]))
        let oldID = try #require(store.preparingPickedMediaProgress?.id)
        try await waitUntil { store.preparingPickedMediaProgress?.done == 1 }
        second.finish()
        try await waitUntil { store.preparingPickedMediaProgress?.done == 2 }
        first.finish()
        try await waitUntil { store.preparingPickedMediaProgress?.done == 3 }
        store.send(.cancelPreparingPickedMedia)

        #expect(!store.isPreparingPickedMedia)
        #expect(store.preparingPickedMediaProgress == nil)
        #expect(store.selectedAssetIDs == ["prior", "first", "second"])
        #expect(store.state.canProceed)

        let newBatch = store.send(.systemPickerFinished([next]))
        late.report(0.9)
        late.finish()
        await oldBatch.finish()
        // 새 선택 직후 메인 큐에 도착하는 이전 세션의 진행 및 완료 알림.
        store.send(.pickedMediaTransferProgress(importID: oldID, index: 0, fraction: 1))
        store.send(.pickedMediaLoaded(importID: oldID, index: 0, media: Self.movie("late")))
        #expect(store.isPreparingPickedMedia)
        #expect(store.preparingPickedMediaProgress?.done == 0)
        #expect(store.preparingPickedMediaProgress?.fractionCompleted == 0)
        #expect(store.selectedAssetIDs == ["prior", "first", "second"])
        next.finish()
        await newBatch.finish()
        #expect(store.selectedAssetIDs == ["prior", "first", "second", "next"])
        #expect(!store.isPreparingPickedMedia && store.state.canProceed)
    }

    private static func movie(_ id: String) -> PickedMedia {
        PickedMedia(id: id, kind: .video, thumbnailData: Data([1]),
                    videoURL: URL(fileURLWithPath: "/tmp/\(id).mov"), capturedAt: nil,
                    duration: 2, displaySize: nil)
    }

    private struct DeferredItem: PickedMediaLoading {
        let id: String
        private let updates = AsyncStream<Double>.makeStream()

        init(_ id: String) { self.id = id }

        func report(_ fraction: Double) { updates.continuation.yield(fraction) }
        func finish() { updates.continuation.finish() }
        func load() async -> PickedMedia? { await load(progress: { _ in }) }

        func load(progress: @escaping @Sendable (Double) -> Void) async -> PickedMedia? {
            // 이미 취소된 요청에서도 뒤늦게 오는 사진 제공자의 콜백을 재현한다.
            await Task {
                for await fraction in updates.stream { progress(fraction) }
            }.value
            return MediaPickerPreviewTests.movie(id)
        }
    }

    @MainActor
    private func waitUntil(_ condition: () -> Bool) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(5))
        while !condition() && clock.now < deadline {
            try await clock.sleep(for: .milliseconds(5))
        }
        try #require(condition())
    }
}
