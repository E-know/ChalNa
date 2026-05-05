import Foundation
import Models
import AVFoundation
import Observation

/// 하나의 `AVPlayer`를 재사용하며 현재 클립을 교체해 재생한다.
/// - `videoURL`이 있는 클립(영상 파일 또는 Live Photo의 paired video) → AVPlayer로 실재생.
/// - `videoURL`이 없는 클립(이미지/스틸) → 타이머 기반 static 진행.
@Observable
public final class ClipPlaybackController {
    public let player: AVPlayer = AVPlayer()

    /// 현재 로드된 클립이 실제 비디오를 갖는지. PreviewPanel에서 AVPlayer vs 썸네일 렌더 분기에 사용.
    public private(set) var hasVideo: Bool = false

    /// 현재 클립 기준 경과 시간(초)을 외부에 전달. TimelineView에서 global playhead로 환산.
    public var onElapsed: ((TimeInterval) -> Void)?
    /// 현재 클립의 재생이 끝났음을 외부에 알림 (영상 종료 or static 타이머 만료).
    public var onClipEnd: (() -> Void)?

    private var currentClipID: Clip.ID?
    private var currentClipDuration: TimeInterval = 3.0
    private var timeObserverToken: Any?
    private var endObserver: NSObjectProtocol?
    private var staticTask: Task<Void, Never>?

    public init() {}

    // MARK: - Intents

    /// 같은 clip이면 no-op. 다른 clip이면 기존 관찰자/타이머를 정리하고 새 아이템 로드.
    public func load(clip: Clip?) {
        if clip?.id == currentClipID { return }
        tearDownObservers()
        cancelStaticTask()
        player.pause()

        currentClipID = clip?.id
        guard let clip else {
            player.replaceCurrentItem(with: nil)
            hasVideo = false
            return
        }

        currentClipDuration = clip.duration
        if let url = clip.videoURL {
            let item = AVPlayerItem(url: url)
            player.replaceCurrentItem(with: item)
            player.seek(to: .zero)
            attachObservers(for: item, clipDuration: clip.duration)
            hasVideo = true
        } else {
            player.replaceCurrentItem(with: nil)
            hasVideo = false
        }
    }

    public func play() {
        if hasVideo {
            player.play()
        } else {
            startStaticTask(duration: currentClipDuration)
        }
    }

    public func pause() {
        player.pause()
        cancelStaticTask()
    }

    public func seekToStart() {
        if hasVideo {
            player.seek(to: .zero)
        }
    }

    // MARK: - Observers

    private func attachObservers(for item: AVPlayerItem, clipDuration: TimeInterval) {
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            let elapsed = CMTimeGetSeconds(time)
            guard elapsed.isFinite else { return }
            self.onElapsed?(elapsed)
            // 클립당 허용 길이를 넘기면 영상이 더 남았어도 종료.
            if elapsed >= clipDuration - 0.02 {
                self.player.pause()
                self.onClipEnd?()
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.onClipEnd?()
        }
    }

    private func tearDownObservers() {
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
        if let obs = endObserver {
            NotificationCenter.default.removeObserver(obs)
            endObserver = nil
        }
    }

    // MARK: - Static fallback

    private func startStaticTask(duration: TimeInterval) {
        cancelStaticTask()
        staticTask = Task { [weak self] in
            let started = Date()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 100_000_000)
                if Task.isCancelled { return }
                let elapsed = Date().timeIntervalSince(started)
                await MainActor.run { [weak self] in
                    guard let self, self.staticTask != nil else { return }
                    self.onElapsed?(elapsed)
                    if elapsed >= duration {
                        self.staticTask = nil
                        self.onClipEnd?()
                    }
                }
                if Date().timeIntervalSince(started) >= duration { return }
            }
        }
    }

    private func cancelStaticTask() {
        staticTask?.cancel()
        staticTask = nil
    }

    // MARK: - Cleanup

    deinit {
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
        }
        if let obs = endObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }
}
