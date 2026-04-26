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

    public init(
        title: String = "",
        clips: [Clip] = [],
        rotations: [Clip.ID: ClipRotation] = [:]
    ) {
        self.title = title
        self.clips = clips
        self.rotations = rotations
    }

    public func replace(clips: [Clip], title: String) {
        self.clips = clips
        self.title = title
        self.rotations = [:]
    }

    public func clear() {
        clips = []
        title = ""
        rotations = [:]
    }

    // MARK: - Rotation

    public func rotation(for id: Clip.ID) -> ClipRotation {
        rotations[id] ?? .r0
    }

    /// 시계 방향으로 한 단계 순환. 4번 호출 시 원위치.
    public func cycleRotation(for id: Clip.ID) {
        rotations[id] = rotation(for: id).next()
    }
}
