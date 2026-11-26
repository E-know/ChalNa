import AnalyticsService
import AppCore
import ComposableArchitecture
import CompositionService
import Foundation
import FilmLibrary
import Models
import PhotosService
import SwiftData
import Testing
@testable import ExportFeature

@MainActor
struct ExportFeatureQuotaTests {
    private let clip = Clip(kind: .video, capturedAt: .distantPast, duration: 1, preset: .jejuSea)
    private let movie = URL(fileURLWithPath: "/tmp/chalna-export-test.mp4")

    @Test func openingConfirmationNeverReservesAndRepeatedConfirmationOnlyRendersSelectedResolutionOnce() async {
        let reservations = LockIsolated(0)
        let renders = LockIsolated<[FilmOutputResolution]>([])
        let (stream, continuation) = AsyncStream<FilmExportEvent>.makeStream()
        let store = TestStore(initialState: ExportFeature.State(resolution: .fourK)) { ExportFeature() } withDependencies: {
            $0.uuid = .incrementing
            $0.date.now = .distantPast
            $0.exportQuotaClient.isUnlocked = { true }
            $0.exportQuotaClient.reserveExport = { reservations.withValue { $0 += 1 }; return .allowed }
            $0.filmComposer = CompositionClient(export: { _, _, _, _, resolution in
                renders.withValue { $0.append(resolution) }
                return stream
            })
        }
        store.exhaustivity = .off
        await store.send(.confirmationAppeared)
        #expect(store.state.phase == .idle && store.state.quotaUnlocked)
        #expect(reservations.value == 0 && renders.value.isEmpty)
        await store.send(.startExport(clips: [], rotations: [:], transforms: [:], clipLabels: [:]))
        #expect(reservations.value == 0)
        let start = ExportFeature.Action.startExport(clips: [clip], rotations: [:], transforms: [:], clipLabels: [:], title: "제주의 오후")
        await store.send(start)
        await store.send(start)
        continuation.yield(.failed("unavailable"))
        continuation.finish()
        await store.receive(\.exportFailed)
        #expect(store.state.phase == .failed)
        #expect(reservations.value == 1 && renders.value == [.fourK])
    }

    @Test(arguments: [ExportQuotaBlockReason.dailyLimit, .weeklyLimit])
    func blockedExportDoesNotStartComposition(reason: ExportQuotaBlockReason) async {
        let renders = LockIsolated(0)
        let analytics = RecordingAnalytics()
        let store = TestStore(initialState: ExportFeature.State()) { ExportFeature() } withDependencies: {
            $0.analyticsTracker = analytics
            $0.exportQuotaClient.reserveExport = { .blocked(reason) }
            $0.filmComposer = CompositionClient(export: { _, _, _, _, _ in
                renders.withValue { $0 += 1 }
                return AsyncStream { $0.finish() }
            })
        }
        store.exhaustivity = .off
        await store.send(.startExport(clips: [clip], rotations: [:], transforms: [:], clipLabels: [:]))
        #expect(renders.value == 0)
        #expect(store.state.phase == .limited(reason))
        #expect(store.state.errorMessage == reason.message)
        #expect(analytics.events.value == [
            .exportFailed(reason: "quota_\(reason)"),
            .exportQuotaBlocked(reason: reason.rawValue, stage: "export_start")
        ])
    }

    @Test func renderCompletionStartsBothSavesOnce() async {
        let archive = RecordingArchive()
        let writes = LockIsolated<[URL]>([])
        let analytics = RecordingAnalytics()
        var state = ExportFeature.State(phase: .exporting)
        let entry = FilmArchiveEntry(id: UUID(), title: "ChalNa", createdAt: .distantPast,
                                     thumbnail: nil, clipCount: 1, liveCount: 0, duration: 1)
        state.entry = entry
        let store = TestStore(initialState: state) { ExportFeature() } withDependencies: {
            $0.analyticsTracker = analytics
            $0.filmArchive = archive
            var photos = PhotoLibraryClient.testValue
            photos.saveVideoToPhotoLibrary = { url in writes.withValue { $0.append(url) }; return .ok }
            $0.photoWriter = photos
        }
        store.exhaustivity = .off
        await store.send(.exportCompleted(movie))
        await store.finish()
        await store.send(.exportCompleted(movie))
        await store.finish()
        #expect(await archive.ids == [entry.id])
        #expect(writes.value == [movie])
        #expect(store.state.phase == .done)
        #expect(analytics.events.value == [.exportCompleted(durationMs: nil), .vlogSavedToLibrary])
    }

    @Test func photoDenialCanRetryTheSameMovieEvenAfterArchivingSucceeded() async {
        let attempts = LockIsolated<[URL]>([])
        var state = ExportFeature.State(phase: .done, exportedURL: movie)
        state.archiveStatus = .saved
        let store = TestStore(initialState: state) { ExportFeature() } withDependencies: {
            var photos = PhotoLibraryClient.testValue
            photos.saveVideoToPhotoLibrary = { url in
                attempts.withValue { urls in
                    urls.append(url)
                    return urls.count == 1 ? .denied : .ok
                }
            }
            $0.photoWriter = photos
        }
        store.exhaustivity = .off
        await store.send(.saveToPhotoLibraryTapped)
        await store.receive(\.saveCompleted)
        #expect(store.state.photoStatus == .denied && store.state.archiveStatus == .saved)
        await store.send(.saveToPhotoLibraryTapped)
        await store.receive(\.saveCompleted)
        await store.send(.saveToPhotoLibraryTapped)
        #expect(store.state.photoStatus == .saved && attempts.value == [movie, movie])
    }

    @Test func archiveRetriesUseOneIDAndDoNotResaveThePhoto() async {
        let entry = FilmArchiveEntry(id: UUID(), title: "ChalNa", createdAt: .distantPast,
                                     thumbnail: nil, clipCount: 1, liveCount: 0, duration: 1)
        let archive = RecordingArchive()
        var state = ExportFeature.State(phase: .done, exportedURL: movie)
        state.entry = entry
        state.photoStatus = .saved
        let store = TestStore(initialState: state) { ExportFeature() } withDependencies: { $0.filmArchive = archive }
        store.exhaustivity = .off
        await store.send(.archiveRequested)
        await store.receive(\.archiveCompleted)
        guard case .failed = store.state.archiveStatus else { Issue.record("Expected archive failure"); return }
        await store.send(.archiveRequested)
        await store.receive(\.archiveCompleted)
        await store.send(.archiveRequested)
        #expect(store.state.archiveStatus == .saved && store.state.photoStatus == .saved)
        let ids = await archive.ids
        #expect(ids == [entry.id, entry.id])
    }

    @Test func archiveCommitsOneRecordAndRemovesItsOwnFile() async throws {
        let container = try ModelContainer(for: Film.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let archive = SwiftDataFilmArchive(container: container)
        let entry = FilmArchiveEntry(id: UUID(), title: "ChalNa", createdAt: .distantPast,
                                     thumbnail: nil, clipCount: 1, liveCount: 0, duration: 1)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mp4")
        do {
            _ = try await archive.archive(entry, movie: url)
            Issue.record("Expected a missing source file to fail")
        } catch {
            #expect(try container.mainContext.fetchCount(FetchDescriptor<Film>()) == 0)
        }
        try Data([1, 2, 3]).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let leavingScreen = Task { try await archive.archive(entry, movie: url) }
        leavingScreen.cancel()
        async let duplicate = archive.archive(entry, movie: url)
        _ = try await leavingScreen.value
        _ = try await duplicate
        let films = try container.mainContext.fetch(FetchDescriptor<Film>())
        #expect(films.count == 1)
        let copy = try #require(films.first?.movieURL)
        defer { try? FileManager.default.removeItem(at: copy) }
        #expect(try Data(contentsOf: copy) == Data(contentsOf: url))
        try await archive.remove(id: entry.id)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Film>()) == 0)
        #expect(!FileManager.default.fileExists(atPath: copy.path))
        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    @Test func retryRestoresMissingMovieAndUpdatesTheExistingCover() async throws {
        let container = try ModelContainer(for: Film.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let archive = SwiftDataFilmArchive(container: container)
        let entry = FilmArchiveEntry(id: UUID(), title: "제주의 오후", createdAt: .distantPast,
                                     thumbnail: Data([2]), clipCount: 1, liveCount: 0, duration: 1)
        let film = Film(id: entry.id, title: entry.title, movieFilename: "films/\(entry.id).mp4",
                        thumbnailData: Data([1]), clipCount: 1, liveCount: 0, totalDurationSeconds: 1)
        container.mainContext.insert(film)
        try container.mainContext.save()

        let source = FileManager.default.temporaryDirectory.appendingPathComponent("\(entry.id).mp4")
        try Data([3]).write(to: source)
        defer { try? FileManager.default.removeItem(at: source) }
        _ = try await archive.archive(entry, movie: source)
        let restored = try #require(film.movieURL)
        defer { try? FileManager.default.removeItem(at: restored) }
        #expect(try Data(contentsOf: restored) == Data([3]))
        #expect(film.thumbnailData == entry.thumbnail)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Film>()) == 1)
    }
}

private struct RecordingAnalytics: AnalyticsTracker {
    let events = LockIsolated<[AnalyticsEvent]>([])

    func log(_ event: AnalyticsEvent) { events.withValue { $0.append(event) } }
    func setUserProperty(_ value: String?, forName name: String) {}
}

private actor RecordingArchive: FilmArchiving {
    private(set) var ids: [UUID] = []
    func archive(_ entry: FilmArchiveEntry, movie: URL) async throws -> Data? {
        ids.append(entry.id)
        if ids.count == 1 { throw CocoaError(.fileWriteUnknown) }
        return nil
    }
}
