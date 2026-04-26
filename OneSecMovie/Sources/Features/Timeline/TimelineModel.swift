import Foundation
import Observation

/// Timeline 편집 화면의 3대 상태.
public enum TimelineState: Equatable {
    case idle
    case playing
    case reordering(draggingClipID: Clip.ID, targetSlotIndex: Int)
}

@Observable
public final class TimelineModel {
    public var title: String
    public var clips: [Clip]
    public var currentIndex: Int
    public var state: TimelineState
    public var playheadSeconds: TimeInterval

    public init(
        title: String = SampleData.filmTitle,
        clips: [Clip] = SampleData.jejuTimeline,
        currentIndex: Int = 0,
        state: TimelineState = .idle
    ) {
        self.title = title
        self.clips = clips
        self.currentIndex = currentIndex
        self.state = state
        self.playheadSeconds = 0
    }

    // MARK: - Derived

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
        if case .playing = state { return true }
        return false
    }

    public var isReordering: Bool {
        if case .reordering = state { return true }
        return false
    }

    public var draggingClipID: Clip.ID? {
        if case let .reordering(id, _) = state { return id }
        return nil
    }

    public var targetSlotIndex: Int? {
        if case let .reordering(_, idx) = state { return idx }
        return nil
    }

    // MARK: - Intents

    public func togglePlay() {
        switch state {
        case .idle:     state = .playing
        case .playing:  state = .idle
        case .reordering: break
        }
    }

    public func select(clipAt index: Int) {
        guard clips.indices.contains(index) else { return }
        currentIndex = index
        playheadSeconds = cumulativeStart(ofClipAt: index)
    }

    public func next() {
        guard currentIndex + 1 < clips.count else { return }
        currentIndex += 1
        playheadSeconds = cumulativeStart(ofClipAt: currentIndex)
    }

    public func previous() {
        guard currentIndex - 1 >= 0 else { return }
        currentIndex -= 1
        playheadSeconds = cumulativeStart(ofClipAt: currentIndex)
    }

    public func cumulativeStart(ofClipAt index: Int) -> TimeInterval {
        var t: TimeInterval = 0
        for i in 0..<min(index, clips.count) { t += clips[i].duration }
        return t
    }

    public func beginReorder(clipID: Clip.ID) {
        guard let idx = clips.firstIndex(where: { $0.id == clipID }) else { return }
        state = .reordering(draggingClipID: clipID, targetSlotIndex: idx + 1)
    }

    public func updateReorderTarget(slot: Int) {
        guard case let .reordering(id, _) = state else { return }
        state = .reordering(draggingClipID: id, targetSlotIndex: max(0, min(slot, clips.count)))
    }

    public func confirmReorder() {
        guard case let .reordering(id, target) = state else { return }
        guard let fromIdx = clips.firstIndex(where: { $0.id == id }) else {
            state = .idle; return
        }
        var newClips = clips
        let clip = newClips.remove(at: fromIdx)
        let insertAt = target > fromIdx ? target - 1 : target
        let clampedInsert = max(0, min(insertAt, newClips.count))
        newClips.insert(clip, at: clampedInsert)
        clips = newClips
        currentIndex = clampedInsert
        state = .idle
    }

    public func cancelReorder() {
        state = .idle
    }

    /// 현재 선택된 클립 제거. 이후 currentIndex는 가능한 한 같은 위치를 가리키도록 클램프.
    public func deleteCurrent() {
        guard clips.indices.contains(currentIndex) else { return }
        clips.remove(at: currentIndex)
        playheadSeconds = 0
        if clips.isEmpty {
            currentIndex = 0
        } else {
            currentIndex = min(currentIndex, clips.count - 1)
        }
        if case .playing = state { state = .idle }
    }

    /// 현재 클립의 길이를 `deltaSeconds`만큼 조정. 0.5s 이상 (상한 없음 — 영상 원본 길이까지 확장 가능).
    public func trimCurrent(deltaSeconds: TimeInterval) {
        guard clips.indices.contains(currentIndex) else { return }
        let clip = clips[currentIndex]
        let newDuration = max(0.5, clip.duration + deltaSeconds)
        clips[currentIndex] = Clip(
            id: clip.id,
            kind: clip.kind,
            capturedAt: clip.capturedAt,
            duration: newDuration,
            preset: clip.preset,
            thumbnailData: clip.thumbnailData,
            videoURL: clip.videoURL,
            locationNote: clip.locationNote
        )
    }

    /// 시뮬레이션 목적의 자동 진행. 재생 중일 때만 동작.
    /// `playheadSeconds`는 전체(0 → totalDuration) 시간을 나타내며, 누적 시간 범위에서
    /// 현재 속한 클립 인덱스를 유도해 자동으로 다음 클립으로 넘어간다.
    public func advancePlayheadSimulated() async {
        let tick: TimeInterval = 0.25
        while isPlaying {
            try? await Task.sleep(nanoseconds: UInt64(tick * 1_000_000_000))
            if !isPlaying { return }
            playheadSeconds = min(playheadSeconds + tick, totalDuration)

            // 누적 타임라인에서 현재 인덱스 재계산.
            var cumulative: TimeInterval = 0
            var newIndex = currentIndex
            for (idx, clip) in clips.enumerated() {
                let clipEnd = cumulative + clip.duration
                if playheadSeconds < clipEnd {
                    newIndex = idx
                    break
                }
                cumulative = clipEnd
                newIndex = idx
            }
            if newIndex != currentIndex {
                currentIndex = newIndex
            }

            if playheadSeconds >= totalDuration {
                state = .idle
                playheadSeconds = 0
                currentIndex = 0
                return
            }
        }
    }
}
