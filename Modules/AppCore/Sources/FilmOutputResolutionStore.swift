import ComposableArchitecture
import Foundation
import Models

enum FilmOutputResolutionStore {
    static let storageKey = "filmOutputResolution"

    static func get(from defaults: UserDefaults = .standard) -> FilmOutputResolution {
        defaults.string(forKey: storageKey).flatMap(FilmOutputResolution.init(rawValue:)) ?? .fullHD
    }

    static func set(_ resolution: FilmOutputResolution, in defaults: UserDefaults = .standard) {
        defaults.set(resolution.rawValue, forKey: storageKey)
    }
}

@DependencyClient
public struct FilmOutputResolutionClient: Sendable {
    public var get: @Sendable () -> FilmOutputResolution = { .fullHD }
    public var set: @Sendable (_ resolution: FilmOutputResolution) -> Void
}

extension FilmOutputResolutionClient: DependencyKey {
    public static let liveValue = Self(
        get: { FilmOutputResolutionStore.get() },
        set: { FilmOutputResolutionStore.set($0) }
    )

    public static let testValue = Self()
}

public extension DependencyValues {
    var filmOutputResolution: FilmOutputResolutionClient {
        get { self[FilmOutputResolutionClient.self] }
        set { self[FilmOutputResolutionClient.self] = newValue }
    }
}
