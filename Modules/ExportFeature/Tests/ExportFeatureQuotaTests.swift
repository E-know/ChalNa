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
            $0.filmStoragePreference.load = { .appAndPhotos }
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
        #expect(store.state.storageMode == .appAndPhotos)
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

    @Test func renderCompletionSavesToPhotosAndArchivesItsIdentifierOnce() async {
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
            photos.saveVideoToPhotoLibrary = { url in
                writes.withValue { $0.append(url) }
                return .ok(localIdentifier: "exported-photo")
            }
            $0.photoWriter = photos
        }
        store.exhaustivity = .off
        await store.send(.exportCompleted(movie))
        await store.receive(\.saveCompleted)
        await store.receive(\.archiveCompleted)
        await store.send(.exportCompleted(movie))
        await store.finish()
        #expect(await archive.records == [.init(id: entry.id, photoAssetIdentifier: "exported-photo", coverSource: movie, keepAppCopy: false)])
        #expect(writes.value == [movie])
        #expect(store.state.phase == .done)
        #expect(store.state.archiveStatus == .saved && store.state.photoStatus == .saved)
        #expect(analytics.events.value == [.exportCompleted(durationMs: nil), .vlogSavedToLibrary])
    }

    @Test(arguments: FilmStorageMode.allCases)
    func photoDenialKeepsAnAppCopyOnlyWhenSelected(storageMode: FilmStorageMode) async {
        let archive = RecordingArchive()
        let attempts = LockIsolated<[URL]>([])
        let entry = FilmArchiveEntry(id: UUID(), title: "ChalNa", createdAt: .distantPast,
                                     thumbnail: nil, clipCount: 1, liveCount: 0, duration: 1)
        var state = ExportFeature.State(phase: .exporting)
        state.entry = entry
        state.storageMode = storageMode
        let store = TestStore(initialState: state) { ExportFeature() } withDependencies: {
            $0.filmArchive = archive
            var photos = PhotoLibraryClient.testValue
            photos.saveVideoToPhotoLibrary = { url in
                attempts.withValue { urls in
                    urls.append(url)
                    return urls.count == 1 ? .denied : .ok(localIdentifier: "retried-photo")
                }
            }
            $0.photoWriter = photos
        }
        store.exhaustivity = .off
        await store.send(.exportCompleted(movie))
        await store.receive(\.saveCompleted, .denied)
        #expect(store.state.photoStatus == .denied)
        var expectedRecords: [RecordingArchive.Record] = []
        let keepAppCopy = storageMode == .appAndPhotos
        if keepAppCopy {
            await store.receive(\.archiveCompleted)
            #expect(store.state.archiveStatus == .saved)
            expectedRecords.append(.init(id: entry.id, photoAssetIdentifier: nil, coverSource: movie, keepAppCopy: true))
        }
        #expect(await archive.records == expectedRecords)
        await store.send(.saveToPhotoLibraryTapped)
        await store.receive(\.saveCompleted)
        await store.receive(\.archiveCompleted)
        await store.send(.saveToPhotoLibraryTapped)
        await store.finish()
        expectedRecords.append(.init(id: entry.id, photoAssetIdentifier: "retried-photo", coverSource: movie, keepAppCopy: keepAppCopy))
        #expect(await archive.records == expectedRecords)
        #expect(store.state.archiveStatus == .saved)
        #expect(store.state.photoStatus == .saved && attempts.value == [movie, movie])
    }

    @Test func archiveRetriesUseOneIDAndDoNotResaveThePhoto() async {
        let entry = FilmArchiveEntry(id: UUID(), title: "ChalNa", createdAt: .distantPast,
                                     thumbnail: nil, clipCount: 1, liveCount: 0, duration: 1)
        let archive = RecordingArchive(failFirst: true)
        let writes = LockIsolated<[URL]>([])
        var state = ExportFeature.State(phase: .exporting)
        state.entry = entry
        let store = TestStore(initialState: state) { ExportFeature() } withDependencies: {
            $0.filmArchive = archive
            var photos = PhotoLibraryClient.testValue
            photos.saveVideoToPhotoLibrary = { url in
                writes.withValue { $0.append(url) }
                return .ok(localIdentifier: "existing-photo")
            }
            $0.photoWriter = photos
        }
        store.exhaustivity = .off
        await store.send(.exportCompleted(movie))
        await store.receive(\.saveCompleted)
        await store.receive(\.archiveCompleted)
        guard case .failed = store.state.archiveStatus else { Issue.record("Expected archive failure"); return }
        await store.send(.archiveRequested)
        await store.receive(\.archiveCompleted)
        await store.send(.archiveRequested)
        await store.finish()
        #expect(store.state.archiveStatus == .saved && store.state.photoStatus == .saved)
        #expect(writes.value == [movie])
        let record = RecordingArchive.Record(id: entry.id, photoAssetIdentifier: "existing-photo", coverSource: movie, keepAppCopy: false)
        #expect(await archive.records == [record, record])
    }

    @Test func homeWaitsForBothSaves() async {
        let (photoResults, photoCompletion) = AsyncStream<FilmPhotoSaveResult>.makeStream()
        let (archiveGate, archiveCompletion) = AsyncStream<Void>.makeStream()
        defer {
            photoCompletion.finish()
            archiveCompletion.finish()
        }
        var state = ExportFeature.State(phase: .exporting)
        state.entry = FilmArchiveEntry(id: UUID(), title: "ChalNa", createdAt: .distantPast,
                                       thumbnail: nil, clipCount: 1, liveCount: 0, duration: 1)
        let store = TestStore(initialState: state) { ExportFeature() } withDependencies: {
            $0.filmArchive = RecordingArchive(waitForCompletion: archiveGate)
            var photos = PhotoLibraryClient.testValue
            photos.saveVideoToPhotoLibrary = { _ in
                var results = photoResults.makeAsyncIterator()
                return await results.next() ?? .denied
            }
            $0.photoWriter = photos
        }
        store.exhaustivity = .off

        await store.send(.exportCompleted(movie))
        store.exhaustivity = .on
        await store.send(.homeTapped)

        photoCompletion.yield(.ok(localIdentifier: "exported-photo"))
        await store.receive(\.saveCompleted) {
            $0.photoAssetIdentifier = "exported-photo"
            $0.photoStatus = .saved
            $0.archiveStatus = .saving
        }
        await store.send(.homeTapped)

        archiveCompletion.finish()
        await store.receive(\.archiveCompleted) { $0.archiveStatus = .saved }
        await store.send(.homeTapped)
        await store.receive(\.delegate, .homeRequested)
    }

    @Test func archiveCommitsOneRecordWithoutCopyingTheMovie() async throws {
        let container = try ModelContainer(for: Film.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let documents = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: documents) }
        let archive = SwiftDataFilmArchive(container: container, documents: documents)
        let entry = FilmArchiveEntry(id: UUID(), title: "ChalNa", createdAt: .distantPast,
                                     thumbnail: Data([1]), clipCount: 1, liveCount: 0, duration: 1)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mp4")
        try Data([1, 2, 3]).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let leavingScreen = Task {
            try await archive.archive(entry, photoAssetIdentifier: "exported-photo", coverSource: url, keepAppCopy: false)
        }
        leavingScreen.cancel()
        async let duplicate = archive.archive(entry, photoAssetIdentifier: "exported-photo", coverSource: url, keepAppCopy: false)
        _ = try await leavingScreen.value
        _ = try await duplicate
        let films = try container.mainContext.fetch(FetchDescriptor<Film>())
        #expect(films.count == 1)
        let film = try #require(films.first)
        #expect(film.photoAssetIdentifier == "exported-photo")
        #expect(film.thumbnailData == entry.thumbnail)
        #expect(film.movieFilename == nil)
        #expect(!FileManager.default.fileExists(atPath: documents.appendingPathComponent("app-films").path))
        try await archive.remove(id: entry.id)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Film>()) == 0)
        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    @Test func archiveKeepsOneAppCopyAndLinksThePhotoOnRetry() async throws {
        let files = FileManager.default
        let documents = files.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try files.createDirectory(at: documents, withIntermediateDirectories: true)
        defer { try? files.removeItem(at: documents) }
        let container = try ModelContainer(for: Film.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let archive = SwiftDataFilmArchive(container: container, documents: documents)
        let entry = FilmArchiveEntry(id: UUID(), title: "ChalNa", createdAt: .distantPast,
                                     thumbnail: Data([1]), clipCount: 1, liveCount: 0, duration: 1)
        let source = documents.appendingPathComponent("export.mp4")
        try Data([1, 2, 3]).write(to: source)

        _ = try await archive.archive(entry, photoAssetIdentifier: nil, coverSource: source, keepAppCopy: true)
        let film = try #require(try container.mainContext.fetch(FetchDescriptor<Film>()).first)
        #expect(film.photoAssetIdentifier == nil)
        let copiedMovie = documents.appendingPathComponent(try #require(film.movieFilename))
        #expect(try Data(contentsOf: copiedMovie) == Data([1, 2, 3]))

        try Data([4, 5, 6]).write(to: source)
        _ = try await archive.archive(entry, photoAssetIdentifier: "retried-photo", coverSource: source, keepAppCopy: true)
        #expect(film.photoAssetIdentifier == "retried-photo")
        #expect(try Data(contentsOf: copiedMovie) == Data([1, 2, 3]))
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Film>()) == 1)

        try SwiftDataFilmArchive.removeLegacyMovieFiles(in: documents)
        var films = archive.films().makeAsyncIterator()
        let savedFilms = try await films.next()
        #expect(savedFilms?.first?.appMovieURL?.standardizedFileURL == copiedMovie.standardizedFileURL)

        try await archive.remove(id: entry.id)
        #expect(!files.fileExists(atPath: copiedMovie.path))
        #expect(files.fileExists(atPath: source.path))
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Film>()) == 0)
    }

    @Test func legacyCleanupRemovesOnlyTheAppMovieDirectory() throws {
        let files = FileManager.default
        let documents = files.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let legacyFilms = documents.appendingPathComponent("films", isDirectory: true)
        let unrelatedFile = documents.appendingPathComponent("other.mp4")
        try files.createDirectory(at: legacyFilms, withIntermediateDirectories: true)
        defer { try? files.removeItem(at: documents) }
        try Data([3]).write(to: legacyFilms.appendingPathComponent("film.mp4"))
        try Data([3]).write(to: legacyFilms.appendingPathComponent(".interrupted.partial"))
        try Data([4]).write(to: unrelatedFile)

        try SwiftDataFilmArchive.removeLegacyMovieFiles(in: documents)
        try SwiftDataFilmArchive.removeLegacyMovieFiles(in: documents)

        #expect(!files.fileExists(atPath: legacyFilms.path))
        #expect(try Data(contentsOf: unrelatedFile) == Data([4]))
    }
}

private struct RecordingAnalytics: AnalyticsTracker {
    let events = LockIsolated<[AnalyticsEvent]>([])

    func log(_ event: AnalyticsEvent) { events.withValue { $0.append(event) } }
    func setUserProperty(_ value: String?, forName name: String) {}
}

private actor RecordingArchive: FilmArchiving {
    struct Record: Equatable, Sendable {
        let id: UUID
        let photoAssetIdentifier: String?
        let coverSource: URL
        let keepAppCopy: Bool
    }

    private let failFirst: Bool
    private let waitForCompletion: AsyncStream<Void>?
    private(set) var records: [Record] = []

    init(failFirst: Bool = false, waitForCompletion: AsyncStream<Void>? = nil) {
        self.failFirst = failFirst
        self.waitForCompletion = waitForCompletion
    }

    func archive(_ entry: FilmArchiveEntry, photoAssetIdentifier: String?, coverSource: URL, keepAppCopy: Bool) async throws -> Data? {
        records.append(Record(id: entry.id, photoAssetIdentifier: photoAssetIdentifier, coverSource: coverSource, keepAppCopy: keepAppCopy))
        if failFirst && records.count == 1 { throw CocoaError(.fileWriteUnknown) }
        if let waitForCompletion {
            var gate = waitForCompletion.makeAsyncIterator()
            _ = await gate.next()
        }
        return nil
    }
}
