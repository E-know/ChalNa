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
    public let sourceDuration: TimeInterval
    public private(set) var trimRange: ClosedRange<TimeInterval>
    public var duration: TimeInterval { trimRange.upperBound - trimRange.lowerBound }
    public var canTrim: Bool { videoURL != nil && sourceDuration > 0 }
    private var minimumTrimDuration: TimeInterval { min(0.5, sourceDuration) }
    public let preset: ThumbnailPreset
    public var thumbnailData: Data?
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
        duration: TimeInterval?,
        preset: ThumbnailPreset,
        thumbnailData: Data? = nil,
        videoURL: URL? = nil,
        locationNote: String? = nil,
        displaySize: CGSize? = nil
    ) {
        self.id = id
        self.kind = kind
        self.capturedAt = capturedAt
        // 길이 미상 클립의 기존 타임라인 재생값은 실제 편집 가능한 원본 길이와 구분한다.
        let seconds = duration ?? 0
        self.sourceDuration = seconds.isFinite ? max(0, seconds) : 0
        self.trimRange = 0...(duration == nil ? 3 : sourceDuration)
        self.preset = preset
        self.thumbnailData = thumbnailData
        self.videoURL = videoURL
        self.locationNote = locationNote
        self.displaySize = displaySize
    }
}

public extension Clip {
    mutating func setTrimRange(_ range: ClosedRange<TimeInterval>) {
        guard canTrim, range.lowerBound.isFinite, range.upperBound.isFinite else { return }
        let start = min(max(0, range.lowerBound), sourceDuration - minimumTrimDuration)
        let end = min(sourceDuration, max(start + minimumTrimDuration, range.upperBound))
        trimRange = start...end
    }

    mutating func setTrimStart(_ seconds: TimeInterval) {
        guard canTrim, seconds.isFinite else { return }
        let start = min(max(0, seconds), trimRange.upperBound - minimumTrimDuration)
        trimRange = start...trimRange.upperBound
    }

    mutating func setTrimEnd(_ seconds: TimeInterval) {
        guard canTrim, seconds.isFinite else { return }
        let end = min(sourceDuration, max(trimRange.lowerBound + minimumTrimDuration, seconds))
        trimRange = trimRange.lowerBound...end
    }

    /// "3.0s" 형태.
    var durationSecondsLabel: String {
        String(format: String(localized: "%.1fs", bundle: AppLocalization.bundle, locale: AppLocalization.locale), duration)
    }

    /// "MM:SS" 형태.
    var durationClockLabel: String {
        let m = Int(duration) / 60
        let s = Int(duration) % 60
        return String(format: "%02d:%02d", m, s)
    }
}
