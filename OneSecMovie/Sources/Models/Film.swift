import Foundation
import SwiftData

/// 사용자가 한 번 export 한 결과 = 라이브러리에 영구 저장되는 단위.
/// SwiftData `@Model` 로 자동 영속화되고, 큰 mp4 파일은 별도 디렉터리에 두고
/// 상대 경로(`movieFilename`) 만 모델에 저장한다.
@Model
public final class Film {
    /// SwiftData 가 자동으로 unique id 를 관리하지만, 외부 파일명과 매칭하려고 별도 UUID 사용.
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var createdAt: Date

    /// `films/<id>.mp4` 형태의 Documents 기준 상대 경로. 절대 경로는 앱 재설치 시 바뀔 수 있음.
    public var movieFilename: String?

    /// 표지 썸네일 (첫 클립). 큰 데이터 가능성이 있어 외부 저장소에 둔다.
    @Attribute(.externalStorage) public var thumbnailData: Data?

    public var clipCount: Int
    public var liveCount: Int
    public var totalDurationSeconds: Double

    public init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = .now,
        movieFilename: String? = nil,
        thumbnailData: Data? = nil,
        clipCount: Int,
        liveCount: Int,
        totalDurationSeconds: Double
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.movieFilename = movieFilename
        self.thumbnailData = thumbnailData
        self.clipCount = clipCount
        self.liveCount = liveCount
        self.totalDurationSeconds = totalDurationSeconds
    }
}

public extension Film {
    /// 디스크 상의 mp4 절대 URL. 파일이 사라졌으면 nil.
    var movieURL: URL? {
        guard let movieFilename else { return nil }
        let url = FilmStorage.documentsURL.appendingPathComponent(movieFilename)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// "8 CLIPS · 00:24" 형식의 메타 라벨.
    var metaLabel: String {
        let m = Int(totalDurationSeconds) / 60
        let s = Int(totalDurationSeconds) % 60
        return String(format: "%d CLIPS · %02d:%02d", clipCount, m, s)
    }
}

// MARK: - 파일 시스템 헬퍼

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
