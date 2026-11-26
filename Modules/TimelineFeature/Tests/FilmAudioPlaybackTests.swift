import AVFoundation
import CompositionService
import Models
import Testing
@testable import TimelineFeature

@MainActor
struct FilmAudioPlaybackTests {
    private final class TestBundle: NSObject {}

    // 카페 테스트 영상 1초에 0.25~0.55초 동안만 440Hz 신호를 담은 MOV.
    private func clip(kind: ClipKind = .video) throws -> Clip {
        let url = try #require(Bundle(for: TestBundle.self).url(forResource: "original-audio", withExtension: "mov"))
        return Clip(kind: kind, capturedAt: Date(), duration: 1, preset: .cafe, videoURL: url)
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
        let url = try await export(clip())
        defer { try? FileManager.default.removeItem(at: url) }
        let asset = AVURLAsset(url: url)
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        let track = try #require(tracks.first)
        #expect(try peak(in: asset, track: track, at: 0.05) < 0.01)
        #expect(try peak(in: asset, track: track, at: 0.35) > 0.1)
    }

    @Test(.serialized, arguments: [ClipKind.video, .live])
    func trimmedExportUsesSelectedFramesAndSound(kind: ClipKind) async throws {
        var clip = try clip(kind: kind)
        clip.setTrimRange(0.3...0.8)
        try #require(clip.trimRange == 0.3...0.8)
        let source = AVURLAsset(url: try #require(clip.videoURL))
        let url = try await export(clip)
        defer { try? FileManager.default.removeItem(at: url) }
        let output = AVURLAsset(url: url)
        let duration = try await output.load(.duration).seconds
        #expect(abs(duration - clip.duration) <= 1.0 / 30)

        let tracks = try await output.loadTracks(withMediaType: .audio)
        let track = try #require(tracks.first)
        #expect(try peak(in: output, track: track, at: 0.05) > 0.1)
        #expect(try peak(in: output, track: track, at: 0.35) < 0.01)

        // 시작·끝 부근의 실제 영상이 제외된 장면보다 해당 원본 프레임에 가까운지 확인한다.
        for (outputTime, excludedTime) in [(0.0, 0.0), (0.4, 0.95)] {
            let rendered = try await centerPixels(output, at: outputTime)
            let expected = try await centerPixels(source, at: 0.3 + outputTime)
            let excluded = try await centerPixels(source, at: excludedTime)
            let selectedError = zip(rendered, expected).reduce(0) { $0 + abs($1.0 - $1.1) }
            let excludedError = zip(rendered, excluded).reduce(0) { $0 + abs($1.0 - $1.1) }
            #expect(selectedError < excludedError)
        }
    }

    @Test(.serialized, arguments: [ClipKind.video, .live])
    func rangeChangeOnLoadedClipSeeksAndEndsOnce(kind: ClipKind) async throws {
        var clip = try clip(kind: kind)
        let playback = ClipPlaybackController()
        playback.load(clip: clip)
        let original = playback.player.currentItem
        clip.setTrimRange(0.3...0.8)
        playback.load(clip: clip)
        let item = try #require(playback.player.currentItem)
        #expect(original !== item)
        #expect(item.forwardPlaybackEndTime.seconds == 0.8)

        var ends = 0
        var elapsed: [Double] = []
        playback.onClipEnd = { ends += 1 }
        playback.onElapsed = { elapsed.append($0) }
        let clock = ContinuousClock()
        let readyBy = clock.now + .seconds(6)
        while (item.status == .unknown || abs(item.currentTime().seconds - 0.3) > 0.01), clock.now < readyBy {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(abs(item.currentTime().seconds - 0.3) <= 0.01)
        playback.play()
        defer { playback.pause() }
        let endBy = clock.now + .seconds(6)
        while ends == 0, clock.now < endBy {
            try await Task.sleep(for: .milliseconds(30))
        }
        try await Task.sleep(for: .milliseconds(150))
        #expect(ends == 1)
        #expect(abs(item.currentTime().seconds - 0.8) <= 1.0 / 30)
        #expect(elapsed.contains { $0 > 0.2 })
        #expect(elapsed.allSatisfy { (0...0.501).contains($0) })
    }

    private func export(_ clip: Clip) async throws -> URL {
        let composer = AVFoundationCompositionService()
        defer { withExtendedLifetime(composer) {} }
        var result: URL?
        for await event in composer.export(clips: [clip]) {
            switch event {
            case .completed(let url): result = url
            case .failed(let message): Issue.record("Export failed: \(message)")
            case .progress: break
            }
        }
        return try #require(result)
    }

    private func centerPixels(_ asset: AVAsset, at seconds: Double) async throws -> [Int] {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let image = try await generator.image(at: CMTime(seconds: seconds, preferredTimescale: 600)).image
        let context = try #require(CGContext(data: nil, width: 24, height: 24, bitsPerComponent: 8, bytesPerRow: 24,
                                             space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: 24, height: 24))
        let pixels = try #require(context.data).assumingMemoryBound(to: UInt8.self)
        return withExtendedLifetime(context) {
            (6..<18).flatMap { row in (6..<18).map { Int(pixels[row * 24 + $0]) } }
        }
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
