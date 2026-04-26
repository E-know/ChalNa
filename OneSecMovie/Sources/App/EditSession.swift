import Observation

/// MediaPicker → Timeline → Export 플로우 전체에서 공유되는 편집 세션.
/// NavigationStack Route에 `[Clip]`을 싣는 대신 환경값으로 흘려보낸다.
@Observable
public final class EditSession {
    public var title: String
    public var clips: [Clip]

    public init(title: String = "", clips: [Clip] = []) {
        self.title = title
        self.clips = clips
    }

    public func replace(clips: [Clip], title: String) {
        self.clips = clips
        self.title = title
    }

    public func clear() {
        clips = []
        title = ""
    }
}
