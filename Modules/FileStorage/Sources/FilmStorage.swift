import Foundation

/// Documents/films 디렉터리에 mp4 를 복사·삭제하는 단순 헬퍼.
/// SwiftData 모델 자체는 mp4 파일을 들고 있지 않고 상대 경로만 보관.
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

    /// 외부(temp) mp4 를 films/<filmID>.mp4 로 복사하고 Documents 기준 상대 경로 반환.
    @discardableResult
    public static func importMovie(from sourceURL: URL, filmID: UUID) throws -> String {
        _ = moviesDirectoryURL
        let filename = "\(filmID.uuidString).mp4"
        let dest = moviesDirectoryURL.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.copyItem(at: sourceURL, to: dest)
        return "films/\(filename)"
    }

    /// 라이브러리에서 Film 을 제거할 때 디스크 mp4 도 같이 청소.
    public static func deleteMovie(filename: String?) {
        guard let filename else { return }
        let url = documentsURL.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
    }
}
