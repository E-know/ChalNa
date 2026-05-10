import Foundation
import Models
import Observation

/// Timeline 편집 화면의 2대 상태.
/// 재정렬 상태는 UIKit `UICollectionView` drag interaction이 시스템 레벨에서 관리하므로 enum case로 노출하지 않는다.
public enum TimelineState: Equatable {
    case idle
    case playing
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

    // MARK: - Intents

    public func togglePlay() {
        switch state {
        case .idle:    state = .playing
        case .playing: state = .idle
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

    /// UICollectionView drop delegate 호출용. clipID 클립을 toIndex 위치로 이동.
    /// from == toIndex 면 no-op. clamping은 [0, clips.count - 1].
    /// currentIndex 가 이동된 클립을 가리키고 있었다면 같이 따라간다.
    public func move(clipID: Clip.ID, toIndex target: Int) {
        guard let from = clips.firstIndex(where: { $0.id == clipID }) else { return }
        let clamped = max(0, min(target, clips.count - 1))
        guard from != clamped else { return }
        let clip = clips.remove(at: from)
        clips.insert(clip, at: clamped)
        if currentIndex == from {
            currentIndex = clamped
        } else if from < currentIndex && clamped >= currentIndex {
            currentIndex -= 1
        } else if from > currentIndex && clamped <= currentIndex {
            currentIndex += 1
        }
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
            locationNote: clip.locationNote,
            displaySize: clip.displaySize
        )
    }

    /// 시뮬레이션 목적의 자동 진행. 재생 중일 때만 동작.
    public func advancePlayheadSimulated() async {
        let tick: TimeInterval = 0.25
        while isPlaying {
            try? await Task.sleep(nanoseconds: UInt64(tick * 1_000_000_000))
            if !isPlaying { return }
            advancePlayhead(by: tick)
        }
    }

    func advancePlayhead(by deltaSeconds: TimeInterval) {
        guard isPlaying else { return }
        playheadSeconds = min(playheadSeconds + deltaSeconds, totalDuration)
        syncCurrentIndexForPlayhead()

        if playheadSeconds >= totalDuration {
            state = .idle
            playheadSeconds = 0
            currentIndex = 0
        }
    }

    private func syncCurrentIndexForPlayhead() {
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
    }
}
