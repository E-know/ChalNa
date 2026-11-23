import ComposableArchitecture
import Foundation

public struct ArchivedFilm: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let title: String
    public let createdAt: Date
    public let movieURL: URL?
    public let thumbnailData: Data?
    public let clipCount: Int
    public let liveCount: Int
    public let totalDurationSeconds: Double

    public init(id: UUID, title: String, createdAt: Date, movieURL: URL?, thumbnailData: Data?,
                clipCount: Int, liveCount: Int, totalDurationSeconds: Double) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.movieURL = movieURL
        self.thumbnailData = thumbnailData
        self.clipCount = clipCount
        self.liveCount = liveCount
        self.totalDurationSeconds = totalDurationSeconds
    }

    public var metaLabel: String {
        let seconds = Int(totalDurationSeconds)
        return String(format: String(localized: "클립 %d개 · %02d:%02d"), clipCount, seconds / 60, seconds % 60)
    }
}

public protocol FilmLibraryReading: Sendable {
    /// 최초 보관함과 이후 변경을 최신 생성순으로 전달한다.
    func films() -> AsyncThrowingStream<[ArchivedFilm], Error>
}

private enum FilmLibraryReaderKey: DependencyKey {
    private struct UnconfiguredReader: FilmLibraryReading {
        func films() -> AsyncThrowingStream<[ArchivedFilm], Error> {
            AsyncThrowingStream { $0.finish(throwing: CocoaError(.fileReadUnknown)) }
        }
    }

    static let liveValue: any FilmLibraryReading = UnconfiguredReader()
}

public extension DependencyValues {
    var filmReader: any FilmLibraryReading {
        get { self[FilmLibraryReaderKey.self] }
        set { self[FilmLibraryReaderKey.self] = newValue }
    }
}
