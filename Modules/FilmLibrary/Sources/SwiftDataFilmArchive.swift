import AppCore
import FileStorage
import Foundation
import Models
import SwiftData

public struct SwiftDataFilmArchive: FilmArchiving, FilmRemoving {
    let container: ModelContainer
    let documents: URL
    private let operations = FilmArchiveOperations()

    public init(container: ModelContainer, documents: URL = FilmStorage.documentsURL) {
        self.container = container
        self.documents = documents
    }

    public static func removeLegacyMovieFiles(in documents: URL = FilmStorage.documentsURL) throws {
        try FilmStorage.removeLegacyMovies(in: documents)
    }

    public func archive(_ entry: FilmArchiveEntry, photoAssetIdentifier: String?, coverSource: URL,
                        keepAppCopy: Bool) async throws -> Data? {
        try await operations.perform(.archive(photoAssetIdentifier, keepAppCopy), id: entry.id) {
            let existing = try await MainActor.run {
                try film(id: entry.id).map { (filename: $0.movieFilename, cover: $0.thumbnailData) }
            }
            let cover: Data?
            if let existing { cover = existing.cover }
            else { cover = await FilmCover.firstFrameJPEG(fromMovieAt: coverSource) ?? entry.thumbnail }

            let filename = keepAppCopy ? try FilmStorage.storeAppCopy(from: coverSource, id: entry.id, in: documents) : nil
            do {
                try await commit(entry, photoAssetIdentifier: photoAssetIdentifier, movieFilename: filename, cover: cover)
                return cover
            } catch {
                if filename != existing?.filename,
                   let copy = FilmStorage.appMovieURL(id: entry.id, filename: filename, in: documents) {
                    try? FileManager.default.removeItem(at: copy)
                }
                throw error
            }
        }
    }

    public func remove(id: UUID) async throws {
        _ = try await operations.perform(.remove, id: id) {
            let filename = try await MainActor.run { try film(id: id)?.movieFilename }
            try await FilmStorage.removingAppCopy(id: id, filename: filename, in: documents) {
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
    private func commit(_ entry: FilmArchiveEntry, photoAssetIdentifier: String?, movieFilename: String?, cover: Data?) throws {
        let context = container.mainContext
        if let existing = try film(id: entry.id) {
            let identifier = photoAssetIdentifier ?? existing.photoAssetIdentifier
            let filename = movieFilename ?? existing.movieFilename
            guard existing.photoAssetIdentifier != identifier || existing.movieFilename != filename else { return }
            existing.photoAssetIdentifier = identifier
            existing.movieFilename = filename
        } else {
            context.insert(Film(
                id: entry.id, title: entry.title, createdAt: entry.createdAt, movieFilename: movieFilename,
                photoAssetIdentifier: photoAssetIdentifier, thumbnailData: cover,
                clipCount: entry.clipCount, liveCount: entry.liveCount, totalDurationSeconds: entry.duration
            ))
        }
        do { try context.save() }
        catch {
            context.rollback()
            throw error
        }
    }
}

/// 화면이 사라져도 시작한 파일 작업은 끝까지 진행한다. 한 필름의 보관·삭제만 직렬화한다.
private actor FilmArchiveOperations {
    enum Kind: Equatable, Sendable { case archive(String?, Bool), remove }
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
