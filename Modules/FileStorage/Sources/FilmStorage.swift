import Foundation

/// 앱에 보관하는 완성 영상 파일을 관리한다.
public enum FilmStorage {
    public static var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    public static func removeLegacyMovies(in documents: URL) throws {
        do {
            try FileManager.default.removeItem(at: documents.appendingPathComponent("films", isDirectory: true))
        } catch let error as CocoaError where error.code == .fileNoSuchFile || error.code == .fileReadNoSuchFile {}
    }

    public static func appMovieURL(id: UUID, filename: String?, in documents: URL) -> URL? {
        guard let filename, filename == appMovieFilename(for: id) else { return nil }
        let url = documents.appendingPathComponent(filename)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), !isDirectory.boolValue else {
            return nil
        }
        return url
    }

    public static func storeAppCopy(from source: URL, id: UUID, in documents: URL) throws -> String {
        let filename = appMovieFilename(for: id)
        if appMovieURL(id: id, filename: filename, in: documents) != nil { return filename }

        let manager = FileManager.default
        let destination = documents.appendingPathComponent(filename)
        let directory = destination.deletingLastPathComponent()
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        let staged = directory.appendingPathComponent(".\(UUID().uuidString).partial")
        defer { try? manager.removeItem(at: staged) }
        try manager.copyItem(at: source, to: staged)
        try manager.moveItem(at: staged, to: destination)
        return filename
    }

    public static func removingAppCopy(id: UUID, filename: String?, in documents: URL,
                                       commit: @Sendable () async throws -> Void) async throws {
        guard let source = appMovieURL(id: id, filename: filename, in: documents) else {
            return try await commit()
        }
        let manager = FileManager.default
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

    private static func appMovieFilename(for id: UUID) -> String {
        "app-films/\(id.uuidString).mp4"
    }
}
