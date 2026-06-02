import AVFoundation
import CoreGraphics
import Foundation
import ImageIO
import Models
import UniformTypeIdentifiers

public struct DevMediaAsset: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let kind: ClipKind
    public let capturedAt: Date
    public let duration: TimeInterval
    public let preset: ThumbnailPreset
    public let locationNote: String?

    public init(
        id: String,
        title: String,
        kind: ClipKind,
        capturedAt: Date,
        duration: TimeInterval,
        preset: ThumbnailPreset,
        locationNote: String?
    ) {
        self.id = id
        self.title = title
        self.kind = kind
        self.capturedAt = capturedAt
        self.duration = duration
        self.preset = preset
        self.locationNote = locationNote
    }
}

public protocol DevMediaSourcing: Sendable {
    func availableAssets() async -> [DevMediaAsset]
    func resolve(assetIDs: [DevMediaAsset.ID]) async throws -> [Clip]
}

public enum DevMediaError: LocalizedError, Equatable, Sendable {
    case missingAssetIDs([DevMediaAsset.ID])
    case missingResource(DevMediaAsset.ID)
    case unreadableVideo(DevMediaAsset.ID)

    public var errorDescription: String? {
        switch self {
        case .missingAssetIDs(let ids):
            return String(localized: "알 수 없는 Dev fixture예요: \(ids.joined(separator: ", "))")
        case .missingResource(let id):
            return String(localized: "Dev fixture 파일을 찾을 수 없어요: \(id)")
        case .unreadableVideo(let id):
            return String(localized: "Dev fixture 영상을 읽을 수 없어요: \(id)")
        }
    }
}

public actor BundledDevMediaSource: DevMediaSourcing {
    private let bundle: Bundle
    private let assets: [DevMediaAsset]

    public init() {
        self.bundle = .module
        self.assets = Self.defaultAssets
    }

    init(bundle: Bundle) {
        self.bundle = bundle
        self.assets = Self.defaultAssets
    }

    public func availableAssets() async -> [DevMediaAsset] {
        assets
    }

    public func resolve(assetIDs: [DevMediaAsset.ID]) async throws -> [Clip] {
        let assetsByID = Dictionary(uniqueKeysWithValues: assets.map { ($0.id, $0) })
        let missing = assetIDs.filter { assetsByID[$0] == nil }
        guard missing.isEmpty else {
            throw DevMediaError.missingAssetIDs(missing)
        }

        var clips: [Clip] = []
        clips.reserveCapacity(assetIDs.count)
        for id in assetIDs {
            guard let asset = assetsByID[id] else { continue }
            clips.append(try await makeClip(from: asset))
        }
        return clips
    }

    private func makeClip(from asset: DevMediaAsset) async throws -> Clip {
        guard let url = fixtureURL(for: asset.id) else {
            throw DevMediaError.missingResource(asset.id)
        }

        let avAsset = AVURLAsset(url: url)
        let duration = try await resolvedDuration(from: avAsset, fallback: asset.duration, id: asset.id)
        let displaySize = try await resolvedDisplaySize(from: avAsset, id: asset.id)
        let thumbnail = await thumbnailData(from: avAsset)

        return Clip(
            kind: asset.kind,
            capturedAt: asset.capturedAt,
            duration: duration,
            preset: asset.preset,
            thumbnailData: thumbnail,
            videoURL: url,
            locationNote: asset.locationNote,
            displaySize: displaySize
        )
    }

    private func fixtureURL(for id: DevMediaAsset.ID) -> URL? {
        for bundle in resourceBundles() {
            if let url = bundle.url(forResource: id, withExtension: "mp4", subdirectory: "DevFixtures")
                ?? bundle.url(forResource: id, withExtension: "mp4")
            {
                return url
            }
        }
        return nil
    }

    private func resourceBundles() -> [Bundle] {
        var bundles = [bundle, .main]
        bundles.append(contentsOf: Bundle.allBundles)
        bundles.append(contentsOf: Bundle.allFrameworks)
        return bundles.reduce(into: []) { result, candidate in
            guard !result.contains(where: { $0.bundleURL == candidate.bundleURL }) else { return }
            result.append(candidate)
        }
    }

    private func resolvedDuration(
        from asset: AVURLAsset,
        fallback: TimeInterval,
        id: DevMediaAsset.ID
    ) async throws -> TimeInterval {
        let duration = (try? await asset.load(.duration)) ?? .zero
        let seconds = CMTimeGetSeconds(duration)
        if seconds.isFinite, seconds > 0 {
            return seconds
        }
        guard fallback > 0 else {
            throw DevMediaError.unreadableVideo(id)
        }
        return fallback
    }

    private func resolvedDisplaySize(from asset: AVURLAsset, id: DevMediaAsset.ID) async throws -> CGSize {
        guard let track = (try? await asset.loadTracks(withMediaType: .video))?.first else {
            throw DevMediaError.unreadableVideo(id)
        }
        let natural = (try? await track.load(.naturalSize)) ?? .zero
        let transform = (try? await track.load(.preferredTransform)) ?? .identity
        let display = natural.applying(transform)
        let size = CGSize(width: abs(display.width), height: abs(display.height))
        guard size.width > 0, size.height > 0 else {
            throw DevMediaError.unreadableVideo(id)
        }
        return size
    }

    private func thumbnailData(from asset: AVURLAsset) async -> Data? {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 480, height: 480)
        guard let image = try? await generator.image(at: .zero).image else {
            return nil
        }
        return Self.jpegData(from: image)
    }

    private nonisolated static func jpegData(from image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }
        CGImageDestinationAddImage(
            destination,
            image,
            [kCGImageDestinationLossyCompressionQuality: 0.75] as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        return data as Data
    }

    private nonisolated static var defaultAssets: [DevMediaAsset] {
        let calendar = Calendar(identifier: .gregorian)
        let base = DateComponents(
            calendar: calendar,
            year: 2026,
            month: 5,
            day: 5,
            hour: 9,
            minute: 30
        ).date ?? Date(timeIntervalSince1970: 1_777_950_600)

        return [
            DevMediaAsset(
                id: "dev-jeju-sea",
                title: String(localized: "협재 바다"),
                kind: .live,
                capturedAt: base,
                duration: 2.4,
                preset: .jejuSea,
                locationNote: String(localized: "Dev · 협재 바다")
            ),
            DevMediaAsset(
                id: "dev-cafe-table",
                title: String(localized: "카페 테이블"),
                kind: .video,
                capturedAt: base.addingTimeInterval(420),
                duration: 2.0,
                preset: .cafe,
                locationNote: String(localized: "Dev · 카페")
            ),
            DevMediaAsset(
                id: "dev-sunset-walk",
                title: String(localized: "노을 산책"),
                kind: .video,
                capturedAt: base.addingTimeInterval(1_080),
                duration: 2.8,
                preset: .sunset,
                locationNote: String(localized: "Dev · 노을")
            ),
            DevMediaAsset(
                id: "dev-forest-light",
                title: String(localized: "숲의 빛"),
                kind: .live,
                capturedAt: base.addingTimeInterval(1_560),
                duration: 2.2,
                preset: .forest,
                locationNote: String(localized: "Dev · 숲길")
            ),
        ]
    }
}
