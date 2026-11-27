import Foundation
import ComposableArchitecture
import Photos
import UIKit
import AVFoundation
import Models
import os

public enum PhotoLibraryAccess: Sendable, Equatable {
    case notDetermined, restricted, denied, authorized, limited

    fileprivate init(_ status: PHAuthorizationStatus) {
        switch status {
        case .notDetermined: self = .notDetermined
        case .restricted: self = .restricted
        case .denied: self = .denied
        case .authorized: self = .authorized
        case .limited: self = .limited
        @unknown default: self = .restricted
        }
    }
}

/// 사용자의 사진 보관함에서 Live Photo / 영상을 읽어오는 @DependencyClient.
/// MediaPickerFeature 에서 `@Dependency(\.photoLibraryClient)` 로 주입.
@DependencyClient
public struct PhotoLibraryClient: Sendable {
    /// 현재 권한 상태.
    public var authorizationStatus: @Sendable () -> PhotoLibraryAccess = { .notDetermined }

    /// 권한 요청 (readWrite).
    public var requestAuthorization: @Sendable () async -> PhotoLibraryAccess = { .denied }

    /// 권한 범위 내의 모든 Live Photo / 영상 asset 메타 (id + kind + capturedAt + pixelSize).
    public var fetchAuthorizedAssets: @Sendable () async -> [PhotoLibraryAsset] = { [] }

    /// 주어진 localIdentifier 배열에 해당하는 Live Photo / 영상 asset 메타.
    /// PHPicker 결과를 PhotoLibraryAsset 으로 변환할 때 사용.
    public var fetchAssets: @Sendable (_ identifiers: [String]) async -> [PhotoLibraryAsset] = { _ in [] }

    /// 특정 asset 의 썸네일 (jpegData).
    public var loadThumbnail: @Sendable (_ assetID: String) async -> Data?

    /// Live Photo paired video 또는 일반 영상의 임시 파일 URL.
    public var loadVideoURL: @Sendable (_ assetID: String, _ kind: PhotoLibraryAssetKind) async -> URL?

    /// 영상 재생 길이(초). 실패 시 nil.
    public var loadVideoDuration: @Sendable (_ url: URL) async -> TimeInterval?

    /// 영상 표시 크기 (preferredTransform 적용 후).
    public var loadDisplaySize: @Sendable (_ url: URL) async -> CGSize?

    /// 특정 asset 의 촬영일.
    public var loadCapturedAt: @Sendable (_ assetID: String) async -> Date?

    /// 완성된 영상을 사진 보관함에 저장.
    public var saveVideoToPhotoLibrary: @Sendable (_ url: URL) async -> PhotoSaveResult = { _ in .denied }

    public var videoAvailability: @Sendable (_ assetID: String) -> PhotoVideoAvailability = { _ in .accessRequired }
    public var loadPlayerItem: @Sendable (_ assetID: String) async -> AVPlayerItem? = { _ in nil }
    /// 임시 공유 파일은 사용이 끝나면 호출자가 삭제한다.
    public var loadShareURL: @Sendable (_ assetID: String) async -> URL? = { _ in nil }
    public var photoLibraryChanges: @Sendable () -> AsyncStream<Void> = { AsyncStream { $0.finish() } }
}

public typealias PhotoSaveResult = FilmPhotoSaveResult

extension PhotoLibraryClient: FilmPhotoWriting {
    public func saveVideo(at url: URL) async -> FilmPhotoSaveResult {
        await saveVideoToPhotoLibrary(url)
    }
}

// MARK: - DependencyValues

extension PhotoLibraryClient: DependencyKey {
    public static let liveValue = PhotoLibraryClient(
        authorizationStatus: {
            PhotoLibraryAccess(PHPhotoLibrary.authorizationStatus(for: .readWrite))
        },
        requestAuthorization: {
            PhotoLibraryAccess(await PHPhotoLibrary.requestAuthorization(for: .readWrite))
        },
        fetchAuthorizedAssets: {
            await Task.detached(priority: .userInitiated) {
                var assets: [PhotoLibraryAsset] = []

                let liveOptions = PHFetchOptions()
                liveOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                let liveFetch = PHAsset.fetchAssets(with: .image, options: liveOptions)
                liveFetch.enumerateObjects { asset, _, _ in
                    guard asset.mediaSubtypes.contains(.photoLive) else { return }
                    assets.append(PhotoLibraryAsset(asset: asset, kind: .livePhoto))
                }

                let videoOptions = PHFetchOptions()
                videoOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                let videoFetch = PHAsset.fetchAssets(with: .video, options: videoOptions)
                videoFetch.enumerateObjects { asset, _, _ in
                    assets.append(PhotoLibraryAsset(asset: asset, kind: .video))
                }

                return assets.sorted { lhs, rhs in
                    (lhs.capturedAt ?? .distantPast) > (rhs.capturedAt ?? .distantPast)
                }
            }.value
        },
        fetchAssets: { identifiers in
            guard !identifiers.isEmpty else { return [] }
            return await Task.detached(priority: .userInitiated) {
                let fetch = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
                var byID: [String: PhotoLibraryAsset] = [:]
                fetch.enumerateObjects { asset, _, _ in
                    let kind: PhotoLibraryAssetKind
                    switch asset.mediaType {
                    case .video: kind = .video
                    case .image where asset.mediaSubtypes.contains(.photoLive): kind = .livePhoto
                    case .image: kind = .image
                    default: kind = .unknown
                    }
                    guard kind.hasMotion else { return }
                    byID[asset.localIdentifier] = PhotoLibraryAsset(asset: asset, kind: kind)
                }
                return identifiers.compactMap { byID[$0] }
            }.value
        },
        loadThumbnail: { assetID in
            await loadThumbnailImpl(forAssetID: assetID)
        },
        loadVideoURL: { assetID, kind in
            guard kind.hasMotion else { return nil }
            return await loadVideoURLImpl(forAssetID: assetID)
        },
        loadVideoDuration: { url in
            let asset = AVURLAsset(url: url)
            do {
                let cm = try await asset.load(.duration)
                let seconds = CMTimeGetSeconds(cm)
                return seconds.isFinite && seconds > 0 ? seconds : nil
            } catch {
                return nil
            }
        },
        loadDisplaySize: { url in
            let asset = AVURLAsset(url: url)
            guard let track = (try? await asset.loadTracks(withMediaType: .video))?.first else {
                return nil
            }
            let natural = (try? await track.load(.naturalSize)) ?? .zero
            let transform = (try? await track.load(.preferredTransform)) ?? .identity
            let display = natural.applying(transform)
            let w = abs(display.width)
            let h = abs(display.height)
            guard w > 0, h > 0 else { return nil }
            return CGSize(width: w, height: h)
        },
        loadCapturedAt: { assetID in
            fetchAsset(with: assetID)?.creationDate
        },
        saveVideoToPhotoLibrary: { url in
            var status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
            if status == .notDetermined {
                status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            }
            guard status == .authorized || status == .limited else { return .denied }
            let identifier = OSAllocatedUnfairLock<String?>(initialState: nil)
            do {
                try await PHPhotoLibrary.shared().performChanges {
                    let request = PHAssetCreationRequest.forAsset()
                    request.addResource(with: .video, fileURL: url, options: nil)
                    let localIdentifier = request.placeholderForCreatedAsset?.localIdentifier
                    identifier.withLock { $0 = localIdentifier }
                }
                guard let localIdentifier = identifier.withLock({ $0 }) else {
                    return .failed(String(localized: "알 수 없는 오류", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
                }
                return .ok(localIdentifier: localIdentifier)
            } catch {
                return .failed(error.localizedDescription)
            }
        },
        videoAvailability: { assetID in
            switch PhotoLibraryAccess(PHPhotoLibrary.authorizationStatus(for: .readWrite)) {
            case .authorized: storedVideoAsset(with: assetID) == nil ? .missing : .available
            case .limited: storedVideoAsset(with: assetID) == nil ? .accessRequired : .available
            case .notDetermined: .authorizationRequired
            case .denied, .restricted: .accessRequired
            }
        },
        loadPlayerItem: { assetID in
            await loadPlayerItemImpl(forAssetID: assetID)
        },
        loadShareURL: { assetID in
            await loadShareURLImpl(forAssetID: assetID)
        },
        photoLibraryChanges: {
            AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
                let library = PHPhotoLibrary.shared()
                let observer = PhotoLibraryChanges(continuation: continuation)
                library.register(observer)
                continuation.onTermination = { _ in library.unregisterChangeObserver(observer) }
            }
        }
    )

    public static let testValue = PhotoLibraryClient()
}

public extension DependencyValues {
    var photoLibraryClient: PhotoLibraryClient {
        get { self[PhotoLibraryClient.self] }
        set { self[PhotoLibraryClient.self] = newValue }
    }
}

// MARK: - Public types

public enum PhotoLibraryAssetKind: Sendable, Hashable {
    case video
    case livePhoto
    case image
    case unknown

    public var hasMotion: Bool { self == .video || self == .livePhoto }
}

public struct PhotoLibraryAsset: Identifiable, Hashable, Sendable {
    public let id: String
    public let kind: PhotoLibraryAssetKind
    public let capturedAt: Date?
    public let pixelSize: CGSize

    public init(id: String, kind: PhotoLibraryAssetKind, capturedAt: Date?, pixelSize: CGSize) {
        self.id = id
        self.kind = kind
        self.capturedAt = capturedAt
        self.pixelSize = pixelSize
    }

    init(asset: PHAsset, kind: PhotoLibraryAssetKind) {
        self.id = asset.localIdentifier
        self.kind = kind
        self.capturedAt = asset.creationDate
        self.pixelSize = CGSize(width: asset.pixelWidth, height: asset.pixelHeight)
    }
}

// MARK: - Internal implementation helpers

private func fetchAsset(with localID: String) -> PHAsset? {
    PHAsset.fetchAssets(withLocalIdentifiers: [localID], options: nil).firstObject
}

private func storedVideoAsset(with localID: String) -> PHAsset? {
    let options = PHFetchOptions()
    options.includeHiddenAssets = true
    let asset = PHAsset.fetchAssets(withLocalIdentifiers: [localID], options: options).firstObject
    return asset?.mediaType == .video ? asset : nil
}

private func loadPlayerItemImpl(forAssetID localID: String) async -> AVPlayerItem? {
    guard !Task.isCancelled, let asset = storedVideoAsset(with: localID) else { return nil }
    let manager = PHImageManager.default()
    let options = PHVideoRequestOptions()
    options.isNetworkAccessAllowed = true
    let (items, continuation) = AsyncStream<AVPlayerItem>.makeStream()
    let request = manager.requestPlayerItem(forVideo: asset, options: options) { item, _ in
        if let item { continuation.yield(item) }
        continuation.finish()
    }
    var iterator = items.makeAsyncIterator()
    let item = await iterator.next()
    if Task.isCancelled {
        manager.cancelImageRequest(request)
        return nil
    }
    return item
}

private func loadShareURLImpl(forAssetID localID: String) async -> URL? {
    guard !Task.isCancelled, let asset = storedVideoAsset(with: localID) else { return nil }
    let resources = PHAssetResource.assetResources(for: asset)
    guard let resource = resources.first(where: { $0.type == .fullSizeVideo })
        ?? resources.first(where: { $0.type == .video }) else { return nil }
    let ext = URL(fileURLWithPath: resource.originalFilename).pathExtension
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension(ext.isEmpty ? "mov" : ext)
    do {
        try await writePHAssetResource(resource, to: url)
        try Task.checkCancellation()
        return url
    } catch {
        try? FileManager.default.removeItem(at: url)
        return nil
    }
}

private final class PhotoLibraryChanges: NSObject, PHPhotoLibraryChangeObserver, Sendable {
    private let continuation: AsyncStream<Void>.Continuation

    init(continuation: AsyncStream<Void>.Continuation) {
        self.continuation = continuation
    }

    func photoLibraryDidChange(_ changeInstance: PHChange) {
        continuation.yield(())
    }
}

private func loadThumbnailImpl(forAssetID localID: String) async -> Data? {
    guard let asset = fetchAsset(with: localID) else { return nil }
    return await withCheckedContinuation { continuation in
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        final class ResumeBox {
            var didResume = false
        }
        let box = ResumeBox()
        manager.requestImage(
            for: asset,
            targetSize: CGSize(width: 480, height: 620),
            contentMode: .aspectFill,
            options: options
        ) { image, info in
            guard !box.didResume else { return }
            if (info?[PHImageResultIsDegradedKey] as? Bool) == true {
                return
            }
            box.didResume = true
            continuation.resume(returning: image?.jpegData(compressionQuality: 0.75))
        }
    }
}

private func loadVideoURLImpl(forAssetID localID: String) async -> URL? {
    guard let asset = fetchAsset(with: localID) else { return nil }

    let resources = PHAssetResource.assetResources(for: asset)
    let preferredTypes: [PHAssetResourceType] = [
        .pairedVideo, .fullSizePairedVideo, .video, .fullSizeVideo
    ]
    guard let resource = preferredTypes
            .lazy.compactMap({ type in resources.first(where: { $0.type == type }) })
            .first
    else {
        return nil
    }

    let destURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("paired-\(UUID().uuidString).mov")
    try? FileManager.default.removeItem(at: destURL)

    do {
        try await writePHAssetResource(resource, to: destURL)
        return destURL
    } catch {
        return nil
    }
}

private func writePHAssetResource(_ resource: PHAssetResource, to url: URL) async throws {
    try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true
        PHAssetResourceManager.default().writeData(for: resource, toFile: url, options: options) { error in
            if let error { cont.resume(throwing: error) } else { cont.resume() }
        }
    }
}
