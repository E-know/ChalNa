import AVFoundation
import OSLog

public extension AVPlayer {
    /// 무음 모드에서도 원본 소리를 들려준다. 오디오 세션은 AVPlayer가 재생을 시작할 때 활성화한다.
    func playWithFilmAudio() {
        let session = AVAudioSession.sharedInstance()
        do {
            if session.category != .playback || session.mode != .moviePlayback {
                try session.setCategory(.playback, mode: .moviePlayback)
            }
        } catch {
            Logger(subsystem: "ios.inho.ChalNa", category: "Playback")
                .error("Failed to configure film audio: \(error.localizedDescription, privacy: .public)")
        }
        play()
    }
}
