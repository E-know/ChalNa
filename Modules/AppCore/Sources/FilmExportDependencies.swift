import AVFoundation
import ComposableArchitecture
import Foundation
import Models

// 실제 구현은 앱 시작 시 주입한다. 테스트와 미리보기는 사진 보관함을 건드리지 않는다.
private enum ComposerKey: TestDependencyKey {
    static let testValue: any FilmComposing = UnavailableComposer()

    private struct UnavailableComposer: FilmComposing {
        func export(clips: [Clip], rotations: [Clip.ID: ClipRotation],
                    transforms: [Clip.ID: ClipTransform], clipLabels: [Clip.ID: ClipLabel],
                    resolution: FilmOutputResolution) -> AsyncStream<FilmExportEvent> {
            AsyncStream { stream in
                stream.yield(.failed(CocoaError(.featureUnsupported).localizedDescription))
                stream.finish()
            }
        }
    }
}

private enum PhotoWriterKey: TestDependencyKey {
    static let testValue: any FilmPhotoWriting = UnavailableWriter()

    private struct UnavailableWriter: FilmPhotoWriting {
        func saveVideo(at url: URL) async -> FilmPhotoSaveResult { .denied }
    }
}

public struct FilmVideoClient: TestDependencyKey, Sendable {
    public var availability: @Sendable (String) -> PhotoVideoAvailability
    public var loadPlayerItem: @Sendable (String) async -> AVPlayerItem?
    public var loadShareURL: @Sendable (String) async -> URL?
    public var changes: @Sendable () -> AsyncStream<Void>
    public var requestAccess: @Sendable () async -> Void

    public init(
        availability: @escaping @Sendable (String) -> PhotoVideoAvailability = { _ in .accessRequired },
        loadPlayerItem: @escaping @Sendable (String) async -> AVPlayerItem? = { _ in nil },
        loadShareURL: @escaping @Sendable (String) async -> URL? = { _ in nil },
        changes: @escaping @Sendable () -> AsyncStream<Void> = { AsyncStream { $0.finish() } },
        requestAccess: @escaping @Sendable () async -> Void = {}
    ) {
        self.availability = availability
        self.loadPlayerItem = loadPlayerItem
        self.loadShareURL = loadShareURL
        self.changes = changes
        self.requestAccess = requestAccess
    }

    public static let testValue = Self()
}

public enum FilmStorageMode: String, CaseIterable, Sendable {
    case photosOnly
    case appAndPhotos
}

@DependencyClient
public struct FilmStoragePreference: Sendable {
    public var load: @Sendable () -> FilmStorageMode = { .photosOnly }
    public var save: @Sendable (_ mode: FilmStorageMode) -> Void = { _ in }
}

extension FilmStoragePreference: DependencyKey {
    private static let storageKey = "filmStorageMode"

    public static let liveValue = Self(
        load: {
            UserDefaults.standard.string(forKey: storageKey)
                .flatMap(FilmStorageMode.init(rawValue:)) ?? .photosOnly
        },
        save: { mode in
            UserDefaults.standard.set(mode.rawValue, forKey: storageKey)
        }
    )

    public static let testValue = Self(load: { .photosOnly }, save: { _ in })
}

public extension DependencyValues {
    var filmComposer: any FilmComposing {
        get { self[ComposerKey.self] }
        set { self[ComposerKey.self] = newValue }
    }

    var photoWriter: any FilmPhotoWriting {
        get { self[PhotoWriterKey.self] }
        set { self[PhotoWriterKey.self] = newValue }
    }

    var filmVideo: FilmVideoClient {
        get { self[FilmVideoClient.self] }
        set { self[FilmVideoClient.self] = newValue }
    }

    var filmStoragePreference: FilmStoragePreference {
        get { self[FilmStoragePreference.self] }
        set { self[FilmStoragePreference.self] = newValue }
    }
}
