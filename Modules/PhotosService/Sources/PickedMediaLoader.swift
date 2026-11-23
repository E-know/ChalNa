import Foundation
import Photos
import AVFoundation
import UIKit
import UniformTypeIdentifiers
import ImageIO

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

public protocol PickedMediaLoading: Sendable {
    var id: String { get }
    func load() async -> PickedMedia?
}

/// 선택기가 일시적으로 허용한 원본을 이 항목이 보유한다. 제한 접근에서도 PHAsset 재조회 없이 읽는다.
public actor PickedMediaLoader: PickedMediaLoading {
    public nonisolated let id: String
    private let provider: NSItemProvider

    public init(assetID: String?, provider: NSItemProvider) {
        self.id = assetID ?? UUID().uuidString
        self.provider = provider
    }

    public func load() async -> PickedMedia? {
        if provider.canLoadObject(ofClass: PHLivePhoto.self) {
            return await loadLivePhoto()
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
            return await loadMovie()
        }
        return nil
    }

    private func loadLivePhoto() async -> PickedMedia? {
        guard let livePhoto = await livePhotoFromProvider() else {
            return nil
        }
        let resources = PHAssetResource.assetResources(for: livePhoto)
        let preferredTypes: [PHAssetResourceType] = [.pairedVideo, .fullSizePairedVideo]
        guard let videoResource = preferredTypes
            .lazy.compactMap({ type in resources.first(where: { $0.type == type }) })
            .first
        else { return nil }

        let destURL = Self.makeTempURL(extension: "mov")
        do {
            try await Self.writeResource(videoResource, to: destURL)
        } catch {
            return nil
        }
        let meta = await Self.loadVideoMetadata(url: destURL)
        // 영상 첫 프레임 추출이 실패해도 Live Photo 는 정지 이미지로 폴백해 썸네일을 보장한다.
        let thumbnail: Data?
        if let metaThumbnail = meta.thumbnail {
            thumbnail = metaThumbnail
        } else {
            thumbnail = await Self.stillImageJPEG(from: resources)
        }
        return PickedMedia(
            id: id,
            kind: .livePhoto,
            thumbnailData: thumbnail,
            videoURL: destURL,
            capturedAt: meta.capturedAt,
            duration: meta.duration,
            displaySize: meta.displaySize
        )
    }

    private func loadMovie() async -> PickedMedia? {
        guard let destURL = await loadMovieFile() else { return nil }
        let meta = await Self.loadVideoMetadata(url: destURL)
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

    private func livePhotoFromProvider() async -> PHLivePhoto? {
        await withCheckedContinuation { continuation in
            provider.loadObject(ofClass: PHLivePhoto.self) { object, _ in
                continuation.resume(returning: object as? PHLivePhoto)
            }
        }
    }

    private func loadMovieFile() async -> URL? {
        await withCheckedContinuation { (cont: CheckedContinuation<URL?, Never>) in
            provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { tempURL, _ in
                guard let tempURL else { cont.resume(returning: nil); return }
                let ext = tempURL.pathExtension.isEmpty ? "mov" : tempURL.pathExtension
                let destURL = Self.makeTempURL(extension: ext)
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

    /// Live Photo 의 정지 이미지 리소스(`.photo`/`.fullSizePhoto`)에서 다운스케일 썸네일 JPEG 를 만든다.
    /// 영상 첫 프레임 추출(`firstFrameJPEG`)이 실패한 경우의 폴백 — Live Photo 는 항상 썸네일을 갖게 된다.
    private static func stillImageJPEG(from resources: [PHAssetResource]) async -> Data? {
        let preferredTypes: [PHAssetResourceType] = [.photo, .fullSizePhoto]
        guard let photoResource = preferredTypes
            .lazy.compactMap({ type in resources.first(where: { $0.type == type }) })
            .first
        else { return nil }

        let ext = (photoResource.originalFilename as NSString).pathExtension
        let destURL = makeTempURL(extension: ext.isEmpty ? "heic" : ext)
        defer { try? FileManager.default.removeItem(at: destURL) }
        do {
            try await writeResource(photoResource, to: destURL)
        } catch {
            return nil
        }
        return downscaledJPEG(fileURL: destURL, maxPixel: 620)
    }

    private static func downscaledJPEG(fileURL: URL, maxPixel: CGFloat) -> Data? {
        guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.75)
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
