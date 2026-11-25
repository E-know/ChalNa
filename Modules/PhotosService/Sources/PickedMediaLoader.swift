import Foundation
import Photos
import AVFoundation
import UIKit
import UniformTypeIdentifiers
import ImageIO
import os

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
    func load(progress: @escaping @Sendable (Double) -> Void) async -> PickedMedia?
}

public extension PickedMediaLoading {
    func load(progress: @escaping @Sendable (Double) -> Void) async -> PickedMedia? {
        await load()
    }
}

public actor PickedMediaLoader: PickedMediaLoading {
    public nonisolated let id: String
    private let assetID: String?
    private let provider: NSItemProvider
    private let idleTimeout: Duration

    public init(assetID: String?, provider: NSItemProvider) {
        self.init(assetID: assetID, provider: provider, idleTimeout: .seconds(60))
    }

    init(assetID: String?, provider: NSItemProvider, idleTimeout: Duration) {
        self.id = assetID ?? UUID().uuidString
        self.assetID = assetID
        self.provider = provider
        self.idleTimeout = idleTimeout
    }

    public func load() async -> PickedMedia? {
        await load(progress: { _ in })
    }

    public func load(progress: @escaping @Sendable (Double) -> Void) async -> PickedMedia? {
        guard !Task.isCancelled else { return nil }
        let asset = accessibleMotionAsset()
        let isSharedAlbum = asset?.sourceType.contains(.typeCloudShared) == true
        let offersLivePhoto = provider.canLoadObject(ofClass: PHLivePhoto.self)
        let highest = OSAllocatedUnfairLock(initialState: 0.0)
        let report: @Sendable (Double) -> Void = { value in
            let advanced = highest.withLock { previous in
                guard value > previous else { return false }
                previous = value
                return true
            }
            if advanced { progress(value) }
        }

        if isSharedAlbum, let asset,
           let item = await attempt(progress: report, { folder, transfer in
               await self.read(asset: asset, in: folder, transfer: transfer)
           }) { return item }

        if offersLivePhoto, let item = await attempt(progress: report, { folder, transfer in
            await self.readLivePhoto(in: folder, transfer: transfer, capturedAt: asset?.creationDate)
        }) { return item }

        if let movieType = provider.registeredTypeIdentifiers.first(where: { UTType($0)?.conforms(to: .movie) == true }) {
            let kind: PhotoLibraryAssetKind = offersLivePhoto || asset?.mediaSubtypes.contains(.photoLive) == true ? .livePhoto : .video
            if let item = await attempt(progress: report, { folder, transfer in
                await self.readMovie(type: movieType, kind: kind, capturedAt: asset?.creationDate, in: folder, transfer: transfer)
            }) { return item }
        }

        guard !isSharedAlbum, let asset else { return nil }
        return await attempt(progress: report) { folder, transfer in
            await self.read(asset: asset, in: folder, transfer: transfer)
        }
    }

    /// 원본 표현마다 독립된 대기 한도·파일을 쓴다. 실패한 요청의 늦은 콜백이 다음 후보를 덮지 않는다.
    private func attempt(progress: @escaping @Sendable (Double) -> Void,
                         _ read: @escaping @Sendable (URL, PickedMediaTransfer) async -> PickedMedia?) async -> PickedMedia? {
        guard !Task.isCancelled else { return nil }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("picked-\(UUID().uuidString)", isDirectory: true)
        do { try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false) }
        catch { return nil }

        let transfer = PickedMediaTransfer(idleTimeout: idleTimeout, onProgress: progress)
        let item = await transfer.run { await read(folder, transfer) }
        // 폴더는 여기에서만 만든다. 취소 뒤 공급자 콜백이 늦게 와도 새 파일을 만들 수 없다.
        guard let item, !Task.isCancelled else {
            try? FileManager.default.removeItem(at: folder)
            return nil
        }
        progress(1)
        return item
    }

    private func readLivePhoto(in folder: URL, transfer: PickedMediaTransfer, capturedAt: Date?) async -> PickedMedia? {
        guard let photo: PHLivePhoto = await loadFromProvider(progress: transfer.progress(upTo: 0.6), start: { complete in
            provider.loadObject(ofClass: PHLivePhoto.self) { object, _ in complete(object as? PHLivePhoto) }
        }) else { return nil }
        return await read(resources: PHAssetResource.assetResources(for: photo), kind: .livePhoto,
                          capturedAt: capturedAt, in: folder, transfer: transfer)
    }

    private func readMovie(type: String, kind: PhotoLibraryAssetKind, capturedAt: Date?,
                           in folder: URL, transfer: PickedMediaTransfer) async -> PickedMedia? {
        let url: URL? = await loadFromProvider(progress: transfer.progress(upTo: 0.95)) { complete in
            provider.loadFileRepresentation(forTypeIdentifier: type) { source, _ in
                guard let source else { complete(nil); return }
                // 이 URL은 공급자의 콜백이 반환되면 만료된다.
                let destination = Self.makeURL(in: folder, extension: source.pathExtension)
                do {
                    try FileManager.default.copyItem(at: source, to: destination)
                    complete(destination)
                } catch {
                    complete(nil)
                }
            }
        }
        guard let url else { return nil }
        return await makeMedia(url: url, kind: kind, capturedAt: capturedAt, resources: [], transfer: transfer)
    }

    private func accessibleMotionAsset() -> PHAsset? {
        guard let assetID else { return nil }
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else { return nil }
        let options = PHFetchOptions()
        options.includeAssetSourceTypes = [.typeUserLibrary, .typeCloudShared, .typeiTunesSynced]
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: options).firstObject,
              asset.mediaType == .video || asset.mediaSubtypes.contains(.photoLive) else { return nil }
        return asset
    }

    private func read(asset: PHAsset, in folder: URL, transfer: PickedMediaTransfer) async -> PickedMedia? {
        await read(resources: PHAssetResource.assetResources(for: asset),
                   kind: asset.mediaType == .video ? .video : .livePhoto, capturedAt: asset.creationDate,
                   in: folder, transfer: transfer)
    }

    private func read(resources: [PHAssetResource], kind: PhotoLibraryAssetKind, capturedAt: Date?,
                      in folder: URL, transfer: PickedMediaTransfer) async -> PickedMedia? {
        let types: [PHAssetResourceType] = kind == .livePhoto ? [.pairedVideo, .fullSizePairedVideo] : [.video, .fullSizeVideo]
        guard !Task.isCancelled,
              let resource = types.lazy.compactMap({ type in resources.first { $0.type == type } }).first else { return nil }
        let url = Self.makeURL(in: folder, extension: (resource.originalFilename as NSString).pathExtension)
        guard await Self.write(resource, to: url, transfer: transfer, upTo: 0.95) else { return nil }
        return await makeMedia(url: url, kind: kind, capturedAt: capturedAt, resources: resources, transfer: transfer)
    }

    private func makeMedia(url: URL, kind: PhotoLibraryAssetKind, capturedAt: Date?, resources: [PHAssetResource],
                           transfer: PickedMediaTransfer) async -> PickedMedia? {
        guard !Task.isCancelled else { return nil }
        let meta = await Self.loadVideoMetadata(url: url)
        var thumbnail = meta.thumbnail
        if thumbnail == nil, meta.displaySize != nil, meta.duration != nil,
           !resources.isEmpty, kind == .livePhoto, !Task.isCancelled {
            thumbnail = await Self.stillImageJPEG(from: resources, in: url.deletingLastPathComponent(), transfer: transfer)
        }
        guard let thumbnail, !Task.isCancelled else { return nil }
        return PickedMedia(id: id, kind: kind, thumbnailData: thumbnail, videoURL: url,
                           capturedAt: meta.capturedAt ?? capturedAt, duration: meta.duration, displaySize: meta.displaySize)
    }

    private func loadFromProvider<Value: Sendable>(progress: @escaping @Sendable (Double) -> Void,
                                                   start: (@escaping @Sendable (Value?) -> Void) -> Progress) async -> Value? {
        guard !Task.isCancelled else { return nil }
        let (values, completion) = AsyncStream<Value>.makeStream()
        let request = start { value in
            if let value { completion.yield(value) }
            completion.finish()
        }
        let observation = request.observe(\.fractionCompleted, options: [.initial, .new]) { value, _ in
            progress(value.fractionCompleted)
        }
        defer {
            observation.invalidate()
            if Task.isCancelled { request.cancel() }
        }
        var iterator = values.makeAsyncIterator()
        return await iterator.next()
    }

    private static func makeURL(in folder: URL, extension ext: String) -> URL {
        folder.appendingPathComponent(UUID().uuidString).appendingPathExtension(ext.isEmpty ? "mov" : ext)
    }

    private static func write(_ resource: PHAssetResource, to url: URL, transfer: PickedMediaTransfer, upTo: Double) async -> Bool {
        guard !Task.isCancelled, FileManager.default.createFile(atPath: url.path, contents: nil) else { return false }
        var keepFile = false
        defer { if !keepFile { try? FileManager.default.removeItem(at: url) } }
        guard let file = try? FileHandle(forWritingTo: url) else { return false }
        let output = OSAllocatedUnfairLock<FileHandle?>(initialState: file)
        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true
        options.progressHandler = transfer.progress(upTo: upTo)
        let (values, completion) = AsyncStream<Bool>.makeStream()
        let manager = PHAssetResourceManager.default()
        let request = manager.requestData(for: resource, options: options) { data in
            do {
                try output.withLock { handle in try handle?.write(contentsOf: data) }
                if !data.isEmpty { transfer.receivedBytes() }
            } catch {
                completion.finish()
            }
        } completionHandler: { error in
            if error == nil { completion.yield(true) }
            completion.finish()
        }
        var iterator = values.makeAsyncIterator()
        let written = await iterator.next() == true && !Task.isCancelled
        if !written { manager.cancelDataRequest(request) }
        do {
            try output.withLock { handle in
                defer { handle = nil }
                try handle?.close()
            }
            keepFile = written
        } catch {}
        return keepFile
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
    private static func stillImageJPEG(from resources: [PHAssetResource], in folder: URL,
                                       transfer: PickedMediaTransfer) async -> Data? {
        let preferredTypes: [PHAssetResourceType] = [.photo, .fullSizePhoto]
        guard let photoResource = preferredTypes
            .lazy.compactMap({ type in resources.first(where: { $0.type == type }) })
            .first
        else { return nil }

        let ext = (photoResource.originalFilename as NSString).pathExtension
        let destURL = makeURL(in: folder, extension: ext.isEmpty ? "heic" : ext)
        defer { try? FileManager.default.removeItem(at: destURL) }
        guard await write(photoResource, to: destURL, transfer: transfer, upTo: 0.98) else { return nil }
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
