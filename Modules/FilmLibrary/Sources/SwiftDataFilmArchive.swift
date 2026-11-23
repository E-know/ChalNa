import AppCore
import FileStorage
import Foundation
import Models
import SwiftData

public struct SwiftDataFilmArchive: FilmArchiving, FilmRemoving {
    let container: ModelContainer
    let coverRepair = FilmLibraryCoverRepair()
    private let operations = FilmArchiveOperations()

    public init(container: ModelContainer) {
        self.container = container
    }

    public func archive(_ entry: FilmArchiveEntry, movie: URL) async throws -> Data? {
        try await operations.perform(.archive, id: entry.id) {
            let existing = try await existingCover(id: entry.id)
            if existing.hasMovie { return existing.cover }
            let filename = try FilmStorage.importMovie(from: movie, filmID: entry.id)
            let url = FilmStorage.documentsURL.appendingPathComponent(filename)
            let cover = await FilmCover.firstFrameJPEG(fromMovieAt: url) ?? entry.thumbnail
            do {
                try await commit(entry, filename: filename, cover: cover)
                return cover
            } catch {
                FilmStorage.deleteMovie(filename: filename)
                throw error
            }
        }
    }

    public func remove(id: UUID) async throws {
        _ = try await operations.perform(.remove, id: id) {
            let filename = try await MainActor.run { try film(id: id)?.movieFilename }
            try await FilmStorage.removingMovie(filename: filename) {
                try await MainActor.run {
                    let context = container.mainContext
                    guard let entry = try film(id: id) else { return }
                    context.delete(entry)
                    do { try context.save() }
                    catch {
                        context.rollback()
                        throw error
                    }
                }
            }
            return nil
        }
    }

    @MainActor
    private func film(id: UUID) throws -> Film? {
        var request = FetchDescriptor<Film>(predicate: #Predicate { $0.id == id })
        request.fetchLimit = 1
        return try container.mainContext.fetch(request).first
    }

    @MainActor
    private func existingCover(id: UUID) throws -> (hasMovie: Bool, cover: Data?) {
        let existing = try film(id: id)
        return (existing?.movieURL != nil, existing?.thumbnailData)
    }

    @MainActor
    private func commit(_ entry: FilmArchiveEntry, filename: String, cover: Data?) throws {
        let context = container.mainContext
        let existing = try film(id: entry.id)
        let film = existing ?? Film(
            id: entry.id, title: entry.title, createdAt: entry.createdAt, thumbnailData: cover,
            clipCount: entry.clipCount, liveCount: entry.liveCount, totalDurationSeconds: entry.duration
        )
        let previousFilename = film.movieFilename
        let previousCover = film.thumbnailData
        film.movieFilename = filename
        if let cover { film.thumbnailData = cover }
        if existing == nil { context.insert(film) }
        do { try context.save() }
        catch {
            if existing == nil { context.delete(film) }
            else {
                film.movieFilename = previousFilename
                film.thumbnailData = previousCover
            }
            throw error
        }
    }
}

/// 화면이 사라져도 시작한 파일 작업은 끝까지 진행한다. 한 필름의 보관·삭제만 직렬화한다.
private actor FilmArchiveOperations {
    enum Kind: Equatable, Sendable { case archive, remove }
    private var pending: [UUID: (kind: Kind, task: Task<Data?, Error>)] = [:]

    func perform(_ kind: Kind, id: UUID, operation: @escaping @Sendable () async throws -> Data?) async throws -> Data? {
        let previous = pending[id]
        if let previous, previous.kind == kind { return try await previous.task.value }
        let job = Task.detached(priority: .utility) {
            if let previous { _ = await previous.task.result }
            return try await operation()
        }
        pending[id] = (kind, job)
        defer { if pending[id]?.task == job { pending[id] = nil } }
        return try await job.value
    }
}
