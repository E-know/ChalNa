import AVFoundation
import CompositionService
import Models
import Testing
@testable import TimelineFeature

@MainActor
struct FilmAudioPlaybackTests {
    private final class TestBundle: NSObject {}

    // 카페 테스트 영상 1초에 0.25~0.55초 동안만 440Hz 신호를 담은 MOV.
    private func clip() throws -> Clip {
        let url = try #require(Bundle(for: TestBundle.self).url(forResource: "original-audio", withExtension: "mov"))
        return Clip(kind: .video, capturedAt: Date(), duration: 1, preset: .cafe, videoURL: url)
    }

    @Test func editingPlaybackUsesMovieAudioEvenIfPreviouslyAmbient() throws {
        let session = AVAudioSession.sharedInstance()
        let original = (session.category, session.mode, session.categoryOptions)
        defer {
            try? session.setCategory(original.0, mode: original.1, options: original.2)
        }
        try session.setCategory(.ambient)
        let playback = ClipPlaybackController()
        playback.load(clip: try clip())
        playback.play()
        defer { playback.pause() }

        #expect(session.category == .playback)
        #expect(session.mode == .moviePlayback)
        #expect(!playback.player.isMuted)
        #expect(playback.player.volume > 0)
    }

    @Test func immediatelyPausingThenReplacingClipKeepsNewItemPaused() async throws {
        let playback = ClipPlaybackController()
        playback.load(clip: try clip())
        playback.play()
        playback.pause()
        playback.load(clip: try clip())
        let replacement = try #require(playback.player.currentItem)
        let tracks = try await replacement.asset.loadTracks(withMediaType: .audio)

        #expect(!tracks.isEmpty)
        #expect(playback.player.currentItem === replacement)
        #expect(playback.player.timeControlStatus == .paused)
        #expect(playback.player.rate == 0)
    }

    @Test func exportedFilmPreservesSourceSoundAtItsOriginalTime() async throws {
        let composer = AVFoundationCompositionService()
        defer { withExtendedLifetime(composer) {} }
        var result: URL?
        for await event in composer.export(clips: [try clip()]) {
            switch event {
            case .completed(let url): result = url
            case .failed(let message): Issue.record("Export failed: \(message)")
            case .progress: break
            }
        }
        let url = try #require(result)
        defer { try? FileManager.default.removeItem(at: url) }
        let asset = AVURLAsset(url: url)
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        let track = try #require(tracks.first)
        #expect(try peak(in: asset, track: track, at: 0.05) < 0.01)
        #expect(try peak(in: asset, track: track, at: 0.35) > 0.1)
    }

    private func peak(in asset: AVURLAsset, track: AVAssetTrack, at start: Double) throws -> Float {
        let reader = try AVAssetReader(asset: asset)
        reader.timeRange = CMTimeRange(start: CMTime(seconds: start, preferredTimescale: 600),
                                       duration: CMTime(value: 1, timescale: 10))
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM, AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true, AVLinearPCMIsNonInterleaved: false,
        ])
        reader.add(output)
        try #require(reader.startReading())
        var maximum: Float = 0
        while let sample = output.copyNextSampleBuffer(), let data = sample.dataBuffer {
            let length = data.dataLength
            guard length > 0 else { continue }
            var samples = [Float](repeating: 0, count: length / MemoryLayout<Float>.size)
            let status = samples.withUnsafeMutableBytes {
                CMBlockBufferCopyDataBytes(data, atOffset: 0, dataLength: length, destination: $0.baseAddress!)
            }
            try #require(status == noErr)
            maximum = samples.reduce(maximum) { max($0, abs($1)) }
        }
        if let error = reader.error { throw error }
        return maximum
    }
}
