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
    @Test func unavailableOriginalCanBeRemovedOrRecoveredWithoutDuplicatingIt() {
        var state = MediaPickerFeature.State(source: .photoLibrary, photoAuthorizationStatus: .limited)
        let reducer = MediaPickerFeature()
        let video = PickedMedia(id: "video", kind: .video, thumbnailData: Data([1]),
                                videoURL: URL(fileURLWithPath: "/tmp/video.mov"), capturedAt: nil,
                                duration: 2, displaySize: nil)
        let failed = PickedMedia(id: "retry", kind: .unknown, thumbnailData: nil, videoURL: nil,
                                 capturedAt: nil, duration: nil, displaySize: nil)
        _ = reducer.reduce(into: &state, action: .photosPickedFromSystemPicker(media: [video, failed]))
        #expect(state.selectedCount == 2)
        #expect(state.hasUnavailableMedia)
        #expect(!state.canProceed)

        let repaired = PickedMedia(id: "retry", kind: .livePhoto, thumbnailData: Data([2]),
                                   videoURL: URL(fileURLWithPath: "/tmp/retry.mov"), capturedAt: nil,
                                   duration: 3, displaySize: nil)
        _ = reducer.reduce(into: &state, action: .photosPickedFromSystemPicker(media: [repaired, failed]))
        #expect(state.selectedAssets.map(\.id) == ["video", "retry"])
        #expect(state.liveCount == 1)
        #expect(state.canProceed)
        let removed = state.selectedAssets[1]
        _ = reducer.reduce(into: &state, action: .photoAssetTapped(removed))
        #expect(state.selectedAssets.map(\.id) == ["video"])
        #expect(state.canProceed)
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
}
