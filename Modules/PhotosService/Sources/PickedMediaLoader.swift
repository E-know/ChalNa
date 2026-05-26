import Foundation
import Photos
import PhotosUI
import AVFoundation
import UIKit
import UniformTypeIdentifiers

/// PHPicker 결과에서 직접 추출한 미디어 한 건.
///
/// `.limited` 사진 권한에서 picker 가 보여주는 사진은 권한 범위 밖일 수 있어서
/// `PHAsset.fetchAssets(withLocalIdentifiers:)` 로 재조회하면 빠진다. 그래서
/// picker 의 `NSItemProvider` 단계에서 paired video / movie 파일을 임시 디렉토리에
/// 미리 꺼내 두고, 이후 파이프라인은 이 값 타입만 보고 동작하도록 한다.
public struct PickedMedia: Sendable, Identifiable, Hashable {
    public let id: String
    public let kind: PhotoLibraryAssetKind
    public let thumbnailData: Data?
    public let videoURL: URL?
    public let capturedAt: Date?
    public let duration: TimeInterval?
    public let displaySize: CGSize?

    public init(
        id: String,
        kind: PhotoLibraryAssetKind,
        thumbnailData: Data?,
        videoURL: URL?,
        capturedAt: Date?,
        duration: TimeInterval?,
        displaySize: CGSize?
    ) {
        self.id = id
        self.kind = kind
        self.thumbnailData = thumbnailData
        self.videoURL = videoURL
        self.capturedAt = capturedAt
        self.duration = duration
        self.displaySize = displaySize
    }
}

public enum PickedMediaLoader {
    /// PHPicker 결과 배열을 picker 가 띄운 순서 그대로 `PickedMedia` 배열로 변환.
    /// 권한 밖 사진도 picker 의 `NSItemProvider` 가 부여한 임시 접근으로 추출 가능.
    ///
    /// - Parameter onProgress: 한 항목 추출이 끝날 때마다 누적 완료 개수(1...N)를 콜백으로 흘려보낸다.
    ///   비동기 동시 추출이라 호출 순서는 picker 순서와 다를 수 있고, MainActor 보장은 호출자 책임.
    public static func load(
        from results: [PHPickerResult],
        onProgress: (@Sendable (Int) -> Void)? = nil
    ) async -> [PickedMedia] {
        actor Counter {
            private(set) var done: Int = 0
            func increment() -> Int {
                done += 1
                return done
            }
        }
        let counter = Counter()

        return await withTaskGroup(of: (Int, PickedMedia?).self) { group in
            for (idx, result) in results.enumerated() {
                group.addTask {
                    let media = await loadOne(result: result)
                    let done = await counter.increment()
                    onProgress?(done)
                    return (idx, media)
                }
            }
            var collected: [(Int, PickedMedia)] = []
            for await (idx, media) in group {
                if let media { collected.append((idx, media)) }
            }
            return collected.sorted { $0.0 < $1.0 }.map(\.1)
        }
    }

    // MARK: - Per-result

    private static func loadOne(result: PHPickerResult) async -> PickedMedia? {
        let provider = result.itemProvider
        let id = result.assetIdentifier ?? UUID().uuidString

        if provider.canLoadObject(ofClass: PHLivePhoto.self) {
            return await loadLivePhoto(provider: provider, id: id)
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
            return await loadMovie(provider: provider, id: id)
        }
        return nil
    }

    private static func loadLivePhoto(provider: NSItemProvider, id: String) async -> PickedMedia? {
        guard let livePhoto = await loadObject(provider: provider, ofClass: PHLivePhoto.self) else {
            return nil
        }
        let resources = PHAssetResource.assetResources(for: livePhoto)
        let preferredTypes: [PHAssetResourceType] = [.pairedVideo, .fullSizePairedVideo]
        guard let videoResource = preferredTypes
            .lazy.compactMap({ type in resources.first(where: { $0.type == type }) })
            .first
        else { return nil }

        let destURL = makeTempURL(extension: "mov")
        do {
            try await writeResource(videoResource, to: destURL)
        } catch {
            return nil
        }
        let meta = await loadVideoMetadata(url: destURL)
        return PickedMedia(
            id: id,
            kind: .livePhoto,
            thumbnailData: meta.thumbnail,
            videoURL: destURL,
            capturedAt: meta.capturedAt,
            duration: meta.duration,
            displaySize: meta.displaySize
        )
    }

    private static func loadMovie(provider: NSItemProvider, id: String) async -> PickedMedia? {
        guard let destURL = await loadMovieFile(provider: provider) else { return nil }
        let meta = await loadVideoMetadata(url: destURL)
        return PickedMedia(
            id: id,
            kind: .video,
            thumbnailData: meta.thumbnail,
            videoURL: destURL,
            capturedAt: meta.capturedAt,
            duration: meta.duration,
            displaySize: meta.displaySize
        )
    }

    // MARK: - NSItemProvider helpers

    private static func loadObject<T: NSItemProviderReading>(
        provider: NSItemProvider,
        ofClass cls: T.Type
    ) async -> T? {
        await withCheckedContinuation { (cont: CheckedContinuation<T?, Never>) in
            provider.loadObject(ofClass: cls) { obj, _ in
                cont.resume(returning: obj as? T)
            }
        }
    }

    /// `loadFileRepresentation` 콜백에서 받는 URL 은 콜백이 끝나면 시스템이 즉시 정리한다.
    /// 그래서 콜백 안에서 동기적으로 우리 임시 폴더로 복사한 뒤 그 URL 만 돌려준다.
    private static func loadMovieFile(provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { (cont: CheckedContinuation<URL?, Never>) in
            provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { tempURL, _ in
                guard let tempURL else { cont.resume(returning: nil); return }
                let ext = tempURL.pathExtension.isEmpty ? "mov" : tempURL.pathExtension
                let destURL = makeTempURL(extension: ext)
                do {
                    try FileManager.default.copyItem(at: tempURL, to: destURL)
                    cont.resume(returning: destURL)
                } catch {
                    cont.resume(returning: nil)
                }
            }
        }
    }

    private static func writeResource(_ resource: PHAssetResource, to url: URL) async throws {
        try? FileManager.default.removeItem(at: url)
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let options = PHAssetResourceRequestOptions()
            options.isNetworkAccessAllowed = true
            PHAssetResourceManager.default().writeData(for: resource, toFile: url, options: options) { error in
                if let error { cont.resume(throwing: error) } else { cont.resume() }
            }
        }
    }

    private static func makeTempURL(extension ext: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("picked-\(UUID().uuidString).\(ext)")
    }

    // MARK: - Metadata from local file

    private struct VideoMetadata {
        var thumbnail: Data?
        var capturedAt: Date?
        var duration: TimeInterval?
        var displaySize: CGSize?
    }

    private static func loadVideoMetadata(url: URL) async -> VideoMetadata {
        let asset = AVURLAsset(url: url)
        async let thumb = firstFrameJPEG(asset: asset)
        async let date  = creationDate(asset: asset)
        async let dur   = loadDuration(asset: asset)
        async let size  = loadDisplaySize(asset: asset)
        return await VideoMetadata(thumbnail: thumb, capturedAt: date, duration: dur, displaySize: size)
    }

    private static func firstFrameJPEG(asset: AVURLAsset) async -> Data? {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 480, height: 620)
        do {
            let result = try await generator.image(at: .zero)
            return UIImage(cgImage: result.image).jpegData(compressionQuality: 0.75)
        } catch {
            return nil
        }
    }

    private static func creationDate(asset: AVURLAsset) async -> Date? {
        do {
            let metadata = try await asset.load(.commonMetadata)
            guard let item = metadata.first(where: { $0.commonKey == .commonKeyCreationDate }) else {
                return nil
            }
            return try await item.load(.dateValue)
        } catch {
            return nil
        }
    }

    private static func loadDuration(asset: AVURLAsset) async -> TimeInterval? {
        do {
            let cm = try await asset.load(.duration)
            let s = CMTimeGetSeconds(cm)
            return s.isFinite && s > 0 ? s : nil
        } catch {
            return nil
        }
    }

    private static func loadDisplaySize(asset: AVURLAsset) async -> CGSize? {
        do {
            guard let track = try await asset.loadTracks(withMediaType: .video).first else { return nil }
            let natural = try await track.load(.naturalSize)
            let transform = try await track.load(.preferredTransform)
            let display = natural.applying(transform)
            let w = abs(display.width), h = abs(display.height)
            return (w > 0 && h > 0) ? CGSize(width: w, height: h) : nil
        } catch {
            return nil
        }
    }
}
