import AVFoundation
import CompositionService
import Foundation
import PhotosService
import Testing

struct DevMediaSourceTests {
    @Test func bundledFixturesResolveToExportableClips() async throws {
        let source = BundledDevMediaSource()
        let assets = await source.availableAssets()

        #expect(!assets.isEmpty)

        let selectedIDs = assets.prefix(3).map(\.id)
        let clips = try await source.resolve(assetIDs: selectedIDs)

        #expect(clips.count == selectedIDs.count)
        for clip in clips {
            let url = try #require(clip.videoURL)
            #expect(FileManager.default.fileExists(atPath: url.path))
            #expect(clip.duration > 0)
            #expect((clip.displaySize?.width ?? 0) > 0)
            #expect((clip.displaySize?.height ?? 0) > 0)
            #expect(clip.thumbnailData != nil)

            let asset = AVURLAsset(url: url)
            let tracks = try await asset.loadTracks(withMediaType: .video)
            #expect(!tracks.isEmpty)
        }
    }

    @Test func resolvePreservesRequestedOrderBeforeCallerSorts() async throws {
        let source = BundledDevMediaSource()
        let assets = await source.availableAssets()
        let requestedAssets = Array(assets.prefix(3).reversed())

        let clips = try await source.resolve(assetIDs: requestedAssets.map(\.id))

        #expect(clips.map(\.capturedAt) == requestedAssets.map(\.capturedAt))
    }

    @Test func unknownFixtureIDFailsExplicitly() async {
        let source = BundledDevMediaSource()

        do {
            _ = try await source.resolve(assetIDs: ["missing-dev-fixture"])
            Issue.record("Expected missing fixture id to throw")
        } catch let error as DevMediaError {
            #expect(error == .missingAssetIDs(["missing-dev-fixture"]))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func resolvedFixtureExportsThroughCompositionService() async throws {
        let source = BundledDevMediaSource()
        let assets = await source.availableAssets()
        let selectedIDs = assets.prefix(3).map(\.id)
        #expect(selectedIDs.count == 3)
        let clips = try await source.resolve(assetIDs: selectedIDs)

        let service = AVFoundationCompositionService()
        var completedURL: URL?
        var failureMessage: String?
        for await event in service.export(clips: clips, rotations: [:]) {
            switch event {
            case .progress:
                break
            case .completed(let url):
                completedURL = url
            case .failed(let message):
                failureMessage = message
            }
        }

        if let failureMessage {
            Issue.record("Export failed: \(failureMessage)")
        }
        let url = try #require(completedURL)
        #expect(FileManager.default.fileExists(atPath: url.path))
    }
}
