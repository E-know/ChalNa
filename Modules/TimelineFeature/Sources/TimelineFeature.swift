import ComposableArchitecture
import AppCore
import Foundation
import Models

/// 타임라인 재생 상태. UICollectionView 재정렬은 시스템 레벨이라 별도 케이스 없음.
public enum TimelineState: Equatable, Sendable {
    case idle
    case playing
}

/// 타임라인 편집 화면 Reducer. 기존 TimelineModel(@Observable) 의 모든 필드와 메서드를 옮긴 형태.
///
/// AVPlayer 래퍼인 `ClipPlaybackController` 는 UI side effect 라 View 에 그대로 유지하고,
/// reducer 는 `playheadElapsedUpdated` / `currentClipEnded` 액션으로 controller 와 동기화한다.
@Reducer
public struct TimelineFeature {
    public init() {}

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
        public var title: String
        public var clips: [Clip]
        public var currentIndex: Int
        public var playbackState: TimelineState
        public var playheadSeconds: TimeInterval
        public var labelEditorClip: Clip?

        @Presents public var deleteAlert: AlertState<Action.DeleteAlert>?

        public init(
            title: String = SampleData.filmTitle,
            clips: [Clip] = SampleData.jejuTimeline,
            currentIndex: Int = 0,
            playbackState: TimelineState = .idle,
            playheadSeconds: TimeInterval = 0
        ) {
            self.title = title
            self.clips = clips
            self.currentIndex = currentIndex
            self.playbackState = playbackState
            self.playheadSeconds = playheadSeconds
        }

        // MARK: Derived

        public var totalDuration: TimeInterval {
            clips.reduce(0) { $0 + $1.duration }
        }

        public var totalDurationLabel: String {
            let m = Int(totalDuration) / 60
            let s = Int(totalDuration) % 60
            return String(format: "%d : %02d", m, s)
        }

        public var playheadLabel: String {
            Self.clock(playheadSeconds)
        }

        public var totalClockLabel: String {
            Self.clock(totalDuration)
        }

        private static func clock(_ seconds: TimeInterval) -> String {
            let tenths = Int((max(0, seconds) * 10).rounded(.toNearestOrAwayFromZero))
            return String(format: "%02d:%02d.%d", tenths / 600, tenths / 10 % 60, tenths % 10)
        }

        public var currentClip: Clip? {
            guard clips.indices.contains(currentIndex) else { return nil }
            return clips[currentIndex]
        }

        public var isPlaying: Bool {
            playbackState == .playing
        }

        public var canEditCurrentClip: Bool { currentClip != nil }

        public func cumulativeStart(ofClipAt index: Int) -> TimeInterval {
            var t: TimeInterval = 0
            for i in 0..<min(index, clips.count) { t += clips[i].duration }
            return t
        }
    }

    // MARK: - Action

    public enum Action {
        case onAppear
        case syncFromSession(clips: [Clip], title: String)
        case togglePlay
        case clipTapped(index: Int)
        case nextTapped
        case previousTapped
        case clipMoved(id: Clip.ID, toIndex: Int)
        case trimCurrent(deltaSeconds: TimeInterval)

        // Delete flow
        case deleteCurrentRequested
        case deleteAlert(PresentationAction<DeleteAlert>)

        @CasePathable
        public enum DeleteAlert: Equatable {
            case confirm(Clip.ID)
        }

        // Playback controller -> reducer
        case playheadElapsedUpdated(TimeInterval)
        case currentClipEnded

        // Navigation intents
        case saveTapped
        case adjustCurrentTapped
        case labelTapped
        case labelDismissed
        case labelCommitted(ClipLabel)
        case playbackInterrupted
        case rotateCurrentTapped
        case delegate(Delegate)

        /// 부모(AppFeature)가 화면 전환으로 해석하는 네비게이션 인텐트.
        public enum Delegate: Equatable {
            case exportRequested
            case clipAdjustRequested(clipID: Clip.ID)
        }
    }

    @Dependency(\.editSession) var session

    // MARK: - Reducer

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .none

            case let .syncFromSession(clips, title):
                guard !clips.isEmpty else { return .none }
                state.title = title
                if state.clips != clips {
                    state.clips = clips
                    state.currentIndex = 0
                    state.playheadSeconds = 0
                    state.playbackState = .idle
                }
                return .none

            case .togglePlay:
                guard !state.clips.isEmpty else { return .none }
                state.playbackState = state.isPlaying ? .idle : .playing
                return .none

            case let .clipTapped(index):
                guard state.clips.indices.contains(index) else { return .none }
                state.currentIndex = index
                state.playheadSeconds = state.cumulativeStart(ofClipAt: index)
                return .none

            case .nextTapped:
                guard state.currentIndex + 1 < state.clips.count else { return .none }
                state.currentIndex += 1
                state.playheadSeconds = state.cumulativeStart(ofClipAt: state.currentIndex)
                return .none

            case .previousTapped:
                guard state.currentIndex - 1 >= 0 else { return .none }
                state.currentIndex -= 1
                state.playheadSeconds = state.cumulativeStart(ofClipAt: state.currentIndex)
                return .none

            case let .clipMoved(id, target):
                guard let from = state.clips.firstIndex(where: { $0.id == id }) else { return .none }
                let clamped = max(0, min(target, state.clips.count - 1))
                guard from != clamped else { return .none }
                let clipElapsed = max(0, state.playheadSeconds - state.cumulativeStart(ofClipAt: state.currentIndex))
                let clip = state.clips.remove(at: from)
                state.clips.insert(clip, at: clamped)
                if state.currentIndex == from {
                    state.currentIndex = clamped
                } else if from < state.currentIndex && clamped >= state.currentIndex {
                    state.currentIndex -= 1
                } else if from > state.currentIndex && clamped <= state.currentIndex {
                    state.currentIndex += 1
                }
                state.playheadSeconds = state.cumulativeStart(ofClipAt: state.currentIndex) + clipElapsed
                session.clips = state.clips
                return .none

            case let .trimCurrent(delta):
                guard state.clips.indices.contains(state.currentIndex) else { return .none }
                let clip = state.clips[state.currentIndex]
                let newDuration = max(0.5, clip.duration + delta)
                state.clips[state.currentIndex] = Clip(
                    id: clip.id,
                    kind: clip.kind,
                    capturedAt: clip.capturedAt,
                    duration: newDuration,
                    preset: clip.preset,
                    thumbnailData: clip.thumbnailData,
                    videoURL: clip.videoURL,
                    locationNote: clip.locationNote,
                    displaySize: clip.displaySize
                )
                session.clips = state.clips
                return .none

            case .deleteCurrentRequested:
                guard let clipID = state.currentClip?.id else { return .none }
                state.playbackState = .idle
                state.deleteAlert = AlertState {
                    TextState("클립을 삭제할까요?")
                } actions: {
                    ButtonState(role: .cancel) { TextState("취소") }
                    ButtonState(role: .destructive, action: .confirm(clipID)) { TextState("삭제") }
                } message: {
                    TextState("삭제한 클립은 현재 타임라인에서 제거됩니다.")
                }
                return .none

            case let .deleteAlert(.presented(.confirm(id))):
                guard let index = state.clips.firstIndex(where: { $0.id == id }) else { return .none }
                state.clips.remove(at: index)
                state.currentIndex = min(index, max(0, state.clips.count - 1))
                state.playheadSeconds = state.cumulativeStart(ofClipAt: state.currentIndex)
                session.clips = state.clips
                return .none

            case .deleteAlert:
                return .none

            case let .playheadElapsedUpdated(elapsed):
                let base = state.cumulativeStart(ofClipAt: state.currentIndex)
                state.playheadSeconds = min(base + elapsed, state.totalDuration)
                return .none

            case .currentClipEnded:
                guard state.isPlaying else { return .none }
                if state.currentIndex + 1 < state.clips.count {
                    state.currentIndex += 1
                    state.playheadSeconds = state.cumulativeStart(ofClipAt: state.currentIndex)
                } else {
                    state.playbackState = .idle
                    state.currentIndex = 0
                    state.playheadSeconds = 0
                }
                return .none

            case .saveTapped:
                guard !state.clips.isEmpty, !state.isPlaying else { return .none }
                return .send(.delegate(.exportRequested))

            case .adjustCurrentTapped:
                guard let clipID = state.currentClip?.id else { return .none }
                state.playbackState = .idle
                return .send(.delegate(.clipAdjustRequested(clipID: clipID)))

            case .labelTapped:
                guard let clip = state.currentClip else { return .none }
                state.playbackState = .idle
                state.labelEditorClip = clip
                return .none

            case .labelDismissed:
                state.labelEditorClip = nil
                return .none

            case .labelCommitted(let label):
                if let id = state.labelEditorClip?.id { session.setLabel(label, for: id) }
                state.labelEditorClip = nil
                return .none

            case .playbackInterrupted:
                state.playbackState = .idle
                return .none

            case .rotateCurrentTapped:
                if let id = state.currentClip?.id { session.cycleRotation(for: id) }
                return .none

            case .delegate:
                return .none
            }
        }
        .ifLet(\.$deleteAlert, action: \.deleteAlert)
    }
}
