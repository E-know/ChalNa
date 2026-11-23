import Foundation

/// Documents/films에는 완성된 MP4를 두고 SwiftData에는 기존과 같은 상대 경로를 저장한다.
public enum FilmStorage {
    public static var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    public static var moviesDirectoryURL: URL {
        let url = documentsURL.appendingPathComponent("films", isDirectory: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    @discardableResult
    public static func importMovie(from sourceURL: URL, filmID: UUID) throws -> String {
        let manager = FileManager.default
        let directory = moviesDirectoryURL
        let filename = "\(filmID.uuidString).mp4"
        let destination = directory.appendingPathComponent(filename)
        if !manager.fileExists(atPath: destination.path) {
            let staged = directory.appendingPathComponent(".\(UUID().uuidString).partial")
            defer { try? manager.removeItem(at: staged) }
            try manager.copyItem(at: sourceURL, to: staged)
            try manager.moveItem(at: staged, to: destination)
        }
        return "films/\(filename)"
    }

    public static func deleteMovie(filename: String?) {
        guard let url = localMovieURL(filename) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private static func localMovieURL(_ filename: String?) -> URL? {
        guard let filename, !filename.isEmpty else { return nil }
        let documents = documentsURL.resolvingSymlinksInPath().standardizedFileURL
        let source = documents.appendingPathComponent(filename).resolvingSymlinksInPath().standardizedFileURL
        guard source.path.hasPrefix(documents.path + "/"), source.pathExtension.lowercased() == "mp4" else { return nil }
        return source
    }

    /// 큰 파일의 이동·정리는 일반 실행자에서 수행한다. 메타데이터 커밋 실패 시 원래 파일을 복원한다.
    public static func removingMovie(filename: String?, commit: @Sendable () async throws -> Void) async throws {
        let manager = FileManager.default
        guard let source = localMovieURL(filename), manager.fileExists(atPath: source.path) else {
            return try await commit()
        }
        let staged = source.deletingLastPathComponent().appendingPathComponent(".\(UUID().uuidString).deleting")
        try manager.moveItem(at: source, to: staged)
        do {
            try await commit()
        } catch {
            try manager.moveItem(at: staged, to: source)
            throw error
        }
        try? manager.removeItem(at: staged)
    }
}
