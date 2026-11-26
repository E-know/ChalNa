import Foundation
import Models
import Testing
@testable import AppCore

struct FilmOutputResolutionStoreTests {
    @Test func defaultsToFullHDWhenUnsetOrInvalid() throws {
        let suiteName = UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        #expect(FilmOutputResolutionStore.get(from: defaults) == .fullHD)
        defaults.set("unknown", forKey: FilmOutputResolutionStore.storageKey)
        #expect(FilmOutputResolutionStore.get(from: defaults) == .fullHD)
    }

    @Test(arguments: FilmOutputResolution.allCases)
    func persistsAndRestoresSelection(_ resolution: FilmOutputResolution) throws {
        let suiteName = UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        FilmOutputResolutionStore.set(resolution, in: defaults)

        let reopened = try #require(UserDefaults(suiteName: suiteName))
        #expect(FilmOutputResolutionStore.get(from: reopened) == resolution)
    }
}
