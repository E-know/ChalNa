import Foundation
import SwiftData

/// 완성 영상의 보관함 항목.
@Model
public final class Film {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var createdAt: Date

    /// 앱에 보관한 영상의 Documents 기준 상대 경로. 구버전 경로도 모델에 남아 있을 수 있다.
    public var movieFilename: String?
    public var photoAssetIdentifier: String?

    /// 표지 썸네일 — 합성 결과물의 첫 프레임(9:16, `FilmCover`). 추출 실패 시 첫 클립 썸네일 폴백.
    /// 큰 데이터 가능성이 있어 외부 저장소에 둔다.
    @Attribute(.externalStorage) public var thumbnailData: Data?

    public var clipCount: Int
    public var liveCount: Int
    public var totalDurationSeconds: Double

    public init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = .now,
        movieFilename: String? = nil,
        photoAssetIdentifier: String? = nil,
        thumbnailData: Data? = nil,
        clipCount: Int,
        liveCount: Int,
        totalDurationSeconds: Double
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.movieFilename = movieFilename
        self.photoAssetIdentifier = photoAssetIdentifier
        self.thumbnailData = thumbnailData
        self.clipCount = clipCount
        self.liveCount = liveCount
        self.totalDurationSeconds = totalDurationSeconds
    }
}
