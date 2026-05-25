import Foundation
import ComposableArchitecture
import Photos
import UIKit
import AVFoundation
import Models

/// 사용자의 사진 보관함에서 Live Photo / 영상을 읽어오는 @DependencyClient.
/// MediaPickerFeature 에서 `@Dependency(\.photoLibraryClient)` 로 주입.
@DependencyClient
public struct PhotoLibraryClient: Sendable {
    /// 현재 권한 상태.
    public var authorizationStatus: @Sendable () -> PHAuthorizationStatus = { .notDetermined }

    /// 권한 요청 (readWrite).
    public var requestAuthorization: @Sendable () async -> PHAuthorizationStatus = { .denied }

    /// 권한 범위 내의 모든 Live Photo / 영상 asset 메타 (id + kind + capturedAt + pixelSize).
    public var fetchAuthorizedAssets: @Sendable () async -> [PhotoLibraryAsset] = { [] }

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
}

public enum PhotoSaveResult: Sendable, Equatable {
    case ok
    case denied
    case failed(String)
}

// MARK: - DependencyValues

extension PhotoLibraryClient: DependencyKey {
    public static let liveValue = PhotoLibraryClient(
        authorizationStatus: {
            PHPhotoLibrary.authorizationStatus(for: .readWrite)
        },
        requestAuthorization: {
            await PHPhotoLibrary.requestAuthorization(for: .readWrite)
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
            let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
            let granted: Bool
            switch status {
            case .authorized, .limited:
                granted = true
            case .notDetermined:
                let new = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
                granted = (new == .authorized || new == .limited)
            default:
                granted = false
            }
            guard granted else { return .denied }
            return await withCheckedContinuation { (cont: CheckedContinuation<PhotoSaveResult, Never>) in
                PHPhotoLibrary.shared().performChanges {
                    PHAssetCreationRequest.creationRequestForAssetFromVideo(atFileURL: url)
                } completionHandler: { success, error in
                    if success {
                        cont.resume(returning: .ok)
                    } else {
                        cont.resume(returning: .failed(error?.localizedDescription ?? "알 수 없는 오류"))
                    }
                }
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
