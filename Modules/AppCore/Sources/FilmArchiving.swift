import ComposableArchitecture
import Foundation

/// 한 번 내보낸 결과만 보관한다. 보관 재시도는 같은 필름 ID와 완성된 파일을 사용한다.
public struct FilmArchiveEntry: Equatable, Sendable {
    public let id: UUID
    public let title: String
    public let createdAt: Date
    public let thumbnail: Data?
    public let clipCount: Int
    public let liveCount: Int
    public let duration: TimeInterval

    public init(id: UUID, title: String, createdAt: Date, thumbnail: Data?, clipCount: Int, liveCount: Int, duration: TimeInterval) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.thumbnail = thumbnail
        self.clipCount = clipCount
        self.liveCount = liveCount
        self.duration = duration
    }
}

public protocol FilmArchiving: Sendable {
    /// 보관함 기록을 저장하고 필요한 경우 앱에 완성본을 복사한다.
    func archive(_ entry: FilmArchiveEntry, photoAssetIdentifier: String?, coverSource: URL,
                 keepAppCopy: Bool) async throws -> Data?
}

private enum FilmArchiveKey: DependencyKey {
    static let liveValue: any FilmArchiving = UnconfiguredArchive()

    private struct UnconfiguredArchive: FilmArchiving {
        func archive(_ entry: FilmArchiveEntry, photoAssetIdentifier: String?, coverSource: URL,
                     keepAppCopy: Bool) async throws -> Data? {
            throw CocoaError(.fileWriteUnknown)
        }
    }
}

public extension DependencyValues {
    var filmArchive: any FilmArchiving {
        get { self[FilmArchiveKey.self] }
        set { self[FilmArchiveKey.self] = newValue }
    }
}

public protocol FilmRemoving: Sendable {
    func remove(id: UUID) async throws
}

private enum FilmRemovalKey: DependencyKey {
    static let liveValue: any FilmRemoving = UnconfiguredRemoval()

    private struct UnconfiguredRemoval: FilmRemoving {
        func remove(id: UUID) async throws {
            throw CocoaError(.fileWriteUnknown)
        }
    }
}

public extension DependencyValues {
    var filmRemoval: any FilmRemoving {
        get { self[FilmRemovalKey.self] }
        set { self[FilmRemovalKey.self] = newValue }
    }
}
