import AppCore
import FileStorage
import Foundation
import Models
import SwiftData

extension SwiftDataFilmArchive: FilmLibraryReading {
    public func films() -> AsyncThrowingStream<[ArchivedFilm], Error> {
        AsyncThrowingStream(bufferingPolicy: .bufferingNewest(1)) { output in
            let observation = Task { @MainActor in
                let context = container.mainContext
                let (updates, invalidate) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
                let token = NotificationCenter.default.addObserver(
                    forName: ModelContext.didSave, object: context, queue: nil
                ) { _ in invalidate.yield(()) }
                defer {
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
                                         photoAssetIdentifier: $0.photoAssetIdentifier,
                                         appMovieURL: FilmStorage.appMovieURL(id: $0.id, filename: $0.movieFilename, in: documents),
                                         thumbnailData: $0.thumbnailData,
                                         clipCount: $0.clipCount, liveCount: $0.liveCount,
                                         totalDurationSeconds: $0.totalDurationSeconds)
                        }
                        output.yield(snapshot)
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
