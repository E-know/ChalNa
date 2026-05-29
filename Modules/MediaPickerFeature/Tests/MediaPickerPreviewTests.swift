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
