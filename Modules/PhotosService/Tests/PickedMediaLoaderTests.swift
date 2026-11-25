import Foundation
import Photos
@testable import PhotosService
import Testing
import UniformTypeIdentifiers
import os

struct PickedMediaLoaderTests {
    @Test func movieProviderCopiesAPlayableFileAndGeneratesAThumbnail() async throws {
        let source = try await fixtureURL()
        let provider = NSItemProvider()
        registerMovie(at: source, on: provider)
        let fractions = OSAllocatedUnfairLock(initialState: [Double]())
        let item = try #require(await PickedMediaLoader(assetID: nil, provider: provider).load { fraction in
            fractions.withLock { $0.append(fraction) }
        })
        let url = try #require(item.videoURL)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        #expect(url != source)
        #expect(try Data(contentsOf: url) == Data(contentsOf: source))
        #expect(item.kind == .video)
        #expect(item.thumbnailData != nil)
        #expect((item.duration ?? 0) > 0)
        #expect(fractions.withLock { $0.last } == 1)
    }

    @Test func stalledLivePhotoFallsBackToItsAdvertisedMovie() async throws {
        let source = try await fixtureURL()
        let provider = StalledLivePhotoProvider()
        registerMovie(at: source, on: provider)
        let loader = PickedMediaLoader(assetID: nil, provider: provider, idleTimeout: .seconds(1))
        let item = try #require(await loader.load())
        let url = try #require(item.videoURL)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        #expect(provider.liveRequest.isCancelled)
        provider.finishLiveRequest()
        #expect(item.kind == .livePhoto)
        #expect(item.thumbnailData != nil)
        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    @Test func cancellingAnUnresponsiveProviderSkipsTheMovieFallback() async throws {
        let provider = StalledLivePhotoProvider()
        let movieLoads = OSAllocatedUnfairLock(initialState: 0)
        provider.registerFileRepresentation(forTypeIdentifier: UTType.mpeg4Movie.identifier,
                                            fileOptions: [], visibility: .all) { complete in
            movieLoads.withLock { $0 += 1 }
            complete(nil, false, CocoaError(.fileReadNoSuchFile))
            return nil
        }
        let loader = PickedMediaLoader(assetID: nil, provider: provider)
        let task = Task { await loader.load() }
        try await waitUntil { provider.hasStarted }
        task.cancel()
        #expect(await task.value == nil)
        try await waitUntil { provider.liveRequest.isCancelled }
        provider.finishLiveRequest()
        #expect(movieLoads.withLock { $0 } == 0)
    }

    @Test func stillImageIsOutsideTheMotionImport() async {
        let provider = NSItemProvider()
        provider.registerDataRepresentation(forTypeIdentifier: UTType.jpeg.identifier, visibility: .all) { complete in
            complete(Data(), nil)
            return nil
        }
        #expect(await PickedMediaLoader(assetID: nil, provider: provider).load() == nil)
    }

    private func fixtureURL() async throws -> URL {
        let clips = try await BundledDevMediaSource().resolve(assetIDs: ["dev-jeju-sea"])
        return try #require(clips.first?.videoURL)
    }

    private func registerMovie(at url: URL, on provider: NSItemProvider) {
        provider.registerFileRepresentation(forTypeIdentifier: UTType.mpeg4Movie.identifier,
                                            fileOptions: [], visibility: .all) { complete in
            complete(url, false, nil)
            return nil
        }
    }

    private func waitUntil(_ predicate: () -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(3)
        while !predicate(), ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(10)) }
        try #require(predicate())
    }
}

private final class StalledLivePhotoProvider: NSItemProvider, @unchecked Sendable {
    typealias Reply = @Sendable ((any NSItemProviderReading)?, (any Error)?) -> Void

    let liveRequest = Progress(totalUnitCount: 100)
    private let reply = OSAllocatedUnfairLock<Reply?>(initialState: nil)
    var hasStarted: Bool { reply.withLock { $0 != nil } }

    override func canLoadObject(ofClass aClass: any NSItemProviderReading.Type) -> Bool {
        aClass == PHLivePhoto.self
    }

    override func loadObject(ofClass aClass: any NSItemProviderReading.Type,
                             completionHandler: @escaping Reply) -> Progress {
        reply.withLock { $0 = completionHandler }
        return liveRequest
    }

    func finishLiveRequest() {
        let completion = reply.withLock { value in
            defer { value = nil }
            return value
        }
        completion?(nil, CocoaError(.userCancelled))
    }
}
