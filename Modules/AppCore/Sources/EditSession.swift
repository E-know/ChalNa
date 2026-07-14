import Observation
import Models

/// MediaPicker → Timeline → Export 플로우 전체에서 공유되는 편집 세션.
/// NavigationStack Route에 `[Clip]`을 싣는 대신 환경값으로 흘려보낸다.
@Observable
public final class EditSession {
    public var title: String
    public var clips: [Clip]
    /// 클립별 사용자 회전 상태. 기본은 r0(원본 그대로). dict miss = `.r0`.
    public var rotations: [Clip.ID: ClipRotation]
    /// 클립별 사용자 라벨. dict miss = `.default`(빈 라벨).
    public var labels: [Clip.ID: ClipLabel]
    /// 클립별 사용자 변환(줌/이동). dict miss = `.fill`(센터 크롭).
    public var transforms: [Clip.ID: ClipTransform]

    public init(
        title: String = "",
        clips: [Clip] = [],
        rotations: [Clip.ID: ClipRotation] = [:],
        labels: [Clip.ID: ClipLabel] = [:],
        transforms: [Clip.ID: ClipTransform] = [:]
    ) {
        self.title = title
        self.clips = clips
        self.rotations = rotations
        self.labels = labels
        self.transforms = transforms
    }

    public func replace(clips: [Clip], title: String) {
        self.clips = clips
        self.title = title
        self.rotations = [:]
        self.labels = [:]
        self.transforms = [:]
    }

    public func clear() {
        clips = []
        title = ""
        rotations = [:]
        labels = [:]
        transforms = [:]
    }

    // MARK: - Rotation

    public func rotation(for id: Clip.ID) -> ClipRotation {
        rotations[id] ?? .r0
    }

    /// 반시계 방향으로 한 단계 순환. 4번 호출 시 원위치.
    public func cycleRotation(for id: Clip.ID) {
        rotations[id] = rotation(for: id).next()
    }

    // MARK: - Label

    public func label(for id: Clip.ID) -> ClipLabel {
        labels[id] ?? .default
    }

    public func setLabel(_ label: ClipLabel, for id: Clip.ID) {
        labels[id] = label
    }

    // MARK: - Transform (zoom/offset)

    public func transform(for id: Clip.ID) -> ClipTransform {
        transforms[id] ?? .fill
    }

    public func setTransform(_ transform: ClipTransform, for id: Clip.ID) {
        transforms[id] = transform
    }

    public func resetTransform(for id: Clip.ID) {
        transforms[id] = nil
    }
}
