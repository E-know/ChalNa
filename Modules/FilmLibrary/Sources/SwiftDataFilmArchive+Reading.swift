import AppCore
import FileStorage
import Foundation
import Models
import SwiftData

public extension Film {
    var movieURL: URL? {
        guard let movieFilename else { return nil }
        let url = FilmStorage.documentsURL.appendingPathComponent(movieFilename)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}

extension SwiftDataFilmArchive: FilmLibraryReading {
    public func films() -> AsyncThrowingStream<[ArchivedFilm], Error> {
        AsyncThrowingStream(bufferingPolicy: .bufferingNewest(1)) { output in
            let observation = Task { @MainActor in
                let context = container.mainContext
                let (updates, invalidate) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
                let token = NotificationCenter.default.addObserver(
                    forName: ModelContext.didSave, object: context, queue: nil
                ) { _ in invalidate.yield(()) }
                var migration: Task<Void, Never>?
                defer {
                    migration?.cancel()
                    NotificationCenter.default.removeObserver(token)
                    invalidate.finish()
                }
                invalidate.yield(())
                do {
                    for await _ in updates {
                        try Task.checkCancellation()
                        let films = try context.fetch(FetchDescriptor<Film>(
                            sortBy: [SortDescriptor(\Film.createdAt, order: .reverse)]
                        ))
                        let snapshot = films.map {
                            ArchivedFilm(id: $0.id, title: $0.title, createdAt: $0.createdAt,
                                         movieURL: $0.movieURL, thumbnailData: $0.thumbnailData,
                                         clipCount: $0.clipCount, liveCount: $0.liveCount,
                                         totalDurationSeconds: $0.totalDurationSeconds)
                        }
                        output.yield(snapshot)
                        if migration == nil, !snapshot.isEmpty {
                            migration = Task { await coverRepair.update(snapshot, context: context) }
                        }
                    }
                    output.finish()
                } catch is CancellationError {
                    output.finish()
                } catch {
                    output.finish(throwing: error)
                }
            }
            output.onTermination = { _ in observation.cancel() }
        }
    }
}

/// 한 보관함을 구독하는 홈·상세가 같은 영상의 표지를 중복 생성하지 않게 한다.
final class FilmLibraryCoverRepair: Sendable {
    @MainActor private var checked: Set<UUID> = []

    @MainActor
    func update(_ snapshot: [ArchivedFilm], context: ModelContext) async {
        for entry in snapshot {
            guard !Task.isCancelled else { return }
            guard let url = entry.movieURL, checked.insert(entry.id).inserted else { continue }
            let cover = await replacement(for: entry.thumbnailData, movie: url)
            guard !Task.isCancelled else {
                checked.remove(entry.id)
                return
            }
            guard let cover else { continue }
            let id = entry.id
            var descriptor = FetchDescriptor<Film>(predicate: #Predicate { $0.id == id })
            descriptor.fetchLimit = 1
            guard let current = try? context.fetch(descriptor).first,
                  current.movieURL == url, current.thumbnailData == entry.thumbnailData else { continue }
            current.thumbnailData = cover
            do { try context.save() }
            catch {
                current.thumbnailData = entry.thumbnailData
                checked.remove(id)
            }
        }
    }

    private func replacement(for thumbnail: Data?, movie: URL) async -> Data? {
        let job = Task.detached(priority: .utility) { () -> Data? in
            guard FilmCover.needsRegeneration(thumbnailData: thumbnail), !Task.isCancelled else { return nil }
            return await FilmCover.firstFrameJPEG(fromMovieAt: movie)
        }
        return await withTaskCancellationHandler { await job.value } onCancel: { job.cancel() }
    }
}
