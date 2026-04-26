import Foundation
import AVFoundation

/// 익스포트 진행 중 외부로 흘려보내는 이벤트.
public enum ExportEvent: Sendable {
    case progress(Double)      // 0.0 → 1.0
    case completed(URL)        // 출력 파일 URL
    case failed(String)        // 사용자에게 보여줄 메시지
}

public enum ExportError: LocalizedError {
    case noVideoClips
    case sessionSetupFailed
    case trackCreationFailed
    case exportFailed(String)

    public var errorDescription: String? {
        switch self {
        case .noVideoClips:
            return "합성 가능한 영상이 없어요. 영상 또는 Live Photo를 골라주세요."
        case .sessionSetupFailed:
            return "내보내기 세션을 준비하지 못했어요."
        case .trackCreationFailed:
            return "비디오 트랙을 만들 수 없어요."
        case .exportFailed(let msg):
            return "저장 중 문제가 생겼어요: \(msg)"
        }
    }
}

public protocol CompositionServicing: Sendable {
    /// 클립 배열을 받아 AVMutableComposition + AVAssetExportSession으로 mp4를 만들고
    /// 진행률/완료/실패 이벤트를 스트림으로 흘려보낸다.
    func export(clips: [Clip]) -> AsyncStream<ExportEvent>
}

/// AVFoundation 기반 실 구현체. PhotosPicker에서 받아온 videoURL들을 이어 붙여 mp4로 내보낸다.
public actor AVFoundationCompositionService: CompositionServicing {
    public init() {}

    public nonisolated func export(clips: [Clip]) -> AsyncStream<ExportEvent> {
        AsyncStream { continuation in
            let task = Task { [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }
                await self.run(clips: clips, continuation: continuation)
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Pipeline

    private func run(
        clips: [Clip],
        continuation: AsyncStream<ExportEvent>.Continuation
    ) async {
        do {
            let (composition, hasContent) = try await buildComposition(clips: clips)
            guard hasContent else {
                throw ExportError.noVideoClips
            }

            let outputURL = Self.makeOutputURL()
            try? FileManager.default.removeItem(at: outputURL)

            guard let session = AVAssetExportSession(
                asset: composition,
                presetName: AVAssetExportPresetHighestQuality
            ) else {
                throw ExportError.sessionSetupFailed
            }
            session.shouldOptimizeForNetworkUse = true

            // 진행률 관찰은 별도 Task로 동시 진행.
            let progressTask = Task { [session] in
                for await state in session.states(updateInterval: 0.15) {
                    if case .exporting(let progress) = state {
                        continuation.yield(.progress(progress.fractionCompleted))
                    }
                }
            }

            do {
                try await session.export(to: outputURL, as: .mp4)
                progressTask.cancel()
            } catch {
                progressTask.cancel()
                throw ExportError.exportFailed(error.localizedDescription)
            }

            continuation.yield(.progress(1.0))
            continuation.yield(.completed(outputURL))
        } catch let err as ExportError {
            continuation.yield(.failed(err.errorDescription ?? "알 수 없는 오류"))
        } catch {
            continuation.yield(.failed(error.localizedDescription))
        }
        continuation.finish()
    }

    private func buildComposition(clips: [Clip]) async throws -> (AVMutableComposition, Bool) {
        let composition = AVMutableComposition()
        guard let compVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw ExportError.trackCreationFailed
        }
        let compAudioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )

        var cursor = CMTime.zero
        var firstTransform: CGAffineTransform?

        for clip in clips {
            guard let videoURL = clip.videoURL else { continue }
            let asset = AVURLAsset(url: videoURL)
            let videoTracks = (try? await asset.loadTracks(withMediaType: .video)) ?? []
            guard let assetVideoTrack = videoTracks.first else { continue }

            let assetDuration = (try? await asset.load(.duration)) ?? .zero
            let assetSeconds = CMTimeGetSeconds(assetDuration)
            guard assetSeconds.isFinite, assetSeconds > 0 else { continue }

            // 클립 모델상의 duration(기본 3s)을 최대값으로 쓰되, 원본이 짧으면 원본 길이.
            let desiredSeconds = min(max(clip.duration, 0.5), assetSeconds)
            let clipDuration = CMTime(seconds: desiredSeconds, preferredTimescale: 600)
            let timeRange = CMTimeRange(start: .zero, duration: clipDuration)

            do {
                try compVideoTrack.insertTimeRange(timeRange, of: assetVideoTrack, at: cursor)
            } catch {
                continue
            }

            if firstTransform == nil {
                firstTransform = try? await assetVideoTrack.load(.preferredTransform)
            }

            if let assetAudioTrack = (try? await asset.loadTracks(withMediaType: .audio))?.first {
                try? compAudioTrack?.insertTimeRange(timeRange, of: assetAudioTrack, at: cursor)
            }

            cursor = CMTimeAdd(cursor, clipDuration)
        }

        let hasContent = cursor > .zero
        if let transform = firstTransform, hasContent {
            compVideoTrack.preferredTransform = transform
        }
        return (composition, hasContent)
    }

    private static func makeOutputURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("moments-\(UUID().uuidString).mp4")
    }
}
