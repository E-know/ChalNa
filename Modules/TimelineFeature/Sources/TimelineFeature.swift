import ComposableArchitecture
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

        // Delete confirmation
        public var pendingDeleteClipID: Clip.ID?
        public var isConfirmingDelete: Bool

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
            self.pendingDeleteClipID = nil
            self.isConfirmingDelete = false
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
            let m = Int(playheadSeconds) / 60
            let s = Int(playheadSeconds) % 60
            return String(format: "%02d:%02d", m, s)
        }

        public var totalClockLabel: String {
            let m = Int(totalDuration) / 60
            let s = Int(totalDuration) % 60
            return String(format: "%02d:%02d", m, s)
        }

        public var currentClip: Clip? {
            guard clips.indices.contains(currentIndex) else { return nil }
            return clips[currentIndex]
        }

        public var isPlaying: Bool {
            playbackState == .playing
        }

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
        case deletePresentedChanged(Bool)
        case deleteConfirmed
        case deleteCancelled

        // Playback controller -> reducer
        case playheadElapsedUpdated(TimeInterval)
        case currentClipEnded

        // Navigation intents
        case dismissTapped
        case saveTapped
        case adjustCurrentTapped
        case rotateCurrentTapped
        case delegate(Delegate)

        /// 부모(AppFeature)가 화면 전환으로 해석하는 네비게이션 인텐트.
        public enum Delegate: Equatable {
            case exportRequested
            case clipAdjustRequested(clipID: Clip.ID)
        }
    }

    @Dependency(\.dismiss) var dismiss

    // MARK: - Reducer

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .none

            case let .syncFromSession(clips, title):
                guard !clips.isEmpty else { return .none }
                if state.clips != clips {
                    state.clips = clips
                    if !title.isEmpty { state.title = title }
                    state.currentIndex = 0
                    state.playheadSeconds = 0
                    state.playbackState = .idle
                }
                return .none

            case .togglePlay:
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
                let clip = state.clips.remove(at: from)
                state.clips.insert(clip, at: clamped)
                if state.currentIndex == from {
                    state.currentIndex = clamped
                } else if from < state.currentIndex && clamped >= state.currentIndex {
                    state.currentIndex -= 1
                } else if from > state.currentIndex && clamped <= state.currentIndex {
                    state.currentIndex += 1
                }
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
                return .none

            case .deleteCurrentRequested:
                state.pendingDeleteClipID = state.currentClip?.id
                state.isConfirmingDelete = state.pendingDeleteClipID != nil
                return .none

            case let .deletePresentedChanged(value):
                state.isConfirmingDelete = value
                if !value { state.pendingDeleteClipID = nil }
                return .none

            case .deleteConfirmed:
                state.isConfirmingDelete = false
                if let pendingID = state.pendingDeleteClipID,
                   let index = state.clips.firstIndex(where: { $0.id == pendingID }) {
                    state.currentIndex = index
                    state.clips.remove(at: index)
                    state.playheadSeconds = 0
                    if state.clips.isEmpty {
                        state.currentIndex = 0
                    } else {
                        state.currentIndex = min(state.currentIndex, state.clips.count - 1)
                    }
                    if state.isPlaying { state.playbackState = .idle }
                }
                state.pendingDeleteClipID = nil
                return .none

            case .deleteCancelled:
                state.isConfirmingDelete = false
                state.pendingDeleteClipID = nil
                return .none

            case let .playheadElapsedUpdated(elapsed):
                let base = state.cumulativeStart(ofClipAt: state.currentIndex)
                state.playheadSeconds = min(base + elapsed, state.totalDuration)
                return .none

            case .currentClipEnded:
                if state.currentIndex + 1 < state.clips.count {
                    state.currentIndex += 1
                    state.playheadSeconds = state.cumulativeStart(ofClipAt: state.currentIndex)
                } else {
                    state.playbackState = .idle
                    state.currentIndex = 0
                    state.playheadSeconds = 0
                }
                return .none

            case .dismissTapped:
                return .run { _ in await dismiss() }

            case .saveTapped:
                return .send(.delegate(.exportRequested))

            case .adjustCurrentTapped:
                guard let clipID = state.currentClip?.id else { return .none }
                return .send(.delegate(.clipAdjustRequested(clipID: clipID)))

            case .rotateCurrentTapped:
                return .none   // View 가 session.cycleRotation

            case .delegate:
                return .none
            }
        }
    }
}
