import CoreGraphics
import Foundation

public enum ClipKind: String, Hashable, Sendable {
    case live
    case video
}

public struct Clip: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let kind: ClipKind
    public let capturedAt: Date
    public let duration: TimeInterval
    public let preset: ThumbnailPreset
    public let thumbnailData: Data?
    /// 실제 영상 합성에 사용할 로컬 파일 URL. nil이면 합성에서 스킵.
    public let videoURL: URL?
    public let locationNote: String?
    /// 원본 영상에 `preferredTransform`을 적용한 후의 표시상 사이즈(width × height).
    /// 합성 시 출력 캔버스 결정과 가운데 정렬용. 샘플데이터/메타 미추출 시 nil.
    public let displaySize: CGSize?

    public init(
        id: UUID = UUID(),
        kind: ClipKind,
        capturedAt: Date,
        duration: TimeInterval,
        preset: ThumbnailPreset,
        thumbnailData: Data? = nil,
        videoURL: URL? = nil,
        locationNote: String? = nil,
        displaySize: CGSize? = nil
    ) {
        self.id = id
        self.kind = kind
        self.capturedAt = capturedAt
        self.duration = duration
        self.preset = preset
        self.thumbnailData = thumbnailData
        self.videoURL = videoURL
        self.locationNote = locationNote
        self.displaySize = displaySize
    }
}

public extension Clip {
    /// "3.0s" 형태.
    var durationSecondsLabel: String {
        String(format: String(localized: "%.1fs"), duration)
    }

    /// "MM:SS" 형태.
    var durationClockLabel: String {
        let m = Int(duration) / 60
        let s = Int(duration) % 60
        return String(format: "%02d:%02d", m, s)
    }
}
