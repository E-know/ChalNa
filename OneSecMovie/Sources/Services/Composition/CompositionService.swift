import Foundation
import AVFoundation
import CoreGraphics

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
    /// 클립 배열과 사용자 회전 dict를 받아 mp4를 만들고 진행률/완료/실패를 스트림으로 흘려보낸다.
    /// renderSize는 첫 클립의 displaySize × 사용자 회전을 따른다.
    func export(clips: [Clip], rotations: [Clip.ID: ClipRotation]) -> AsyncStream<ExportEvent>
}

public extension CompositionServicing {
    /// 회전 정보 없는 호출. 모든 클립이 r0(원본 그대로)로 처리된다. 테스트/구버전 호출 호환용.
    func export(clips: [Clip]) -> AsyncStream<ExportEvent> {
        export(clips: clips, rotations: [:])
    }
}

/// AVFoundation 기반 실 구현체. PhotosPicker에서 받아온 videoURL들을 이어 붙여 mp4로 내보낸다.
public actor AVFoundationCompositionService: CompositionServicing {
    public init() {}

    public nonisolated func export(
        clips: [Clip],
        rotations: [Clip.ID: ClipRotation]
    ) -> AsyncStream<ExportEvent> {
        AsyncStream { continuation in
            let task = Task { [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }
                await self.run(clips: clips, rotations: rotations, continuation: continuation)
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Pipeline

    private func run(
        clips: [Clip],
        rotations: [Clip.ID: ClipRotation],
        continuation: AsyncStream<ExportEvent>.Continuation
    ) async {
        do {
            let built = try await buildComposition(clips: clips, rotations: rotations)
            guard built.hasContent else {
                throw ExportError.noVideoClips
            }

            let outputURL = Self.makeOutputURL()
            try? FileManager.default.removeItem(at: outputURL)

            guard let session = AVAssetExportSession(
                asset: built.composition,
                presetName: AVAssetExportPresetHighestQuality
            ) else {
                throw ExportError.sessionSetupFailed
            }
            session.shouldOptimizeForNetworkUse = true
            session.videoComposition = built.videoComposition

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

    // MARK: - Build

    private struct BuiltComposition {
        let composition: AVMutableComposition
        let videoComposition: AVMutableVideoComposition
        let hasContent: Bool
    }

    private func buildComposition(
        clips: [Clip],
        rotations: [Clip.ID: ClipRotation]
    ) async throws -> BuiltComposition {
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

        // 1) 첫 유효 클립의 displaySize와 회전을 미리 살펴 renderSize를 결정한다.
        let renderSize = await Self.resolveRenderSize(clips: clips, rotations: rotations)

        // 2) 시간순으로 트랙을 채우면서 클립별 layerInstruction 누적.
        var cursor = CMTime.zero
        var layerInstructions: [(timeRange: CMTimeRange, transform: CGAffineTransform)] = []

        for clip in clips {
            guard let videoURL = clip.videoURL else { continue }
            let asset = AVURLAsset(url: videoURL)
            let videoTracks = (try? await asset.loadTracks(withMediaType: .video)) ?? []
            guard let assetVideoTrack = videoTracks.first else { continue }

            let assetDuration = (try? await asset.load(.duration)) ?? .zero
            let assetSeconds = CMTimeGetSeconds(assetDuration)
            guard assetSeconds.isFinite, assetSeconds > 0 else { continue }

            let desiredSeconds = min(max(clip.duration, 0.5), assetSeconds)
            let clipDuration = CMTime(seconds: desiredSeconds, preferredTimescale: 600)
            let timeRange = CMTimeRange(start: .zero, duration: clipDuration)

            do {
                try compVideoTrack.insertTimeRange(timeRange, of: assetVideoTrack, at: cursor)
            } catch {
                continue
            }

            if let assetAudioTrack = (try? await asset.loadTracks(withMediaType: .audio))?.first {
                try? compAudioTrack?.insertTimeRange(timeRange, of: assetAudioTrack, at: cursor)
            }

            // 트랙 메타: preferredTransform과 naturalSize.
            let preferredTransform = (try? await assetVideoTrack.load(.preferredTransform)) ?? .identity
            let naturalSize = (try? await assetVideoTrack.load(.naturalSize)) ?? renderSize
            let userRotation = rotations[clip.id] ?? .r0

            let transform = Self.transform(
                naturalSize: naturalSize,
                preferredTransform: preferredTransform,
                rotation: userRotation,
                renderSize: renderSize
            )

            let placedRange = CMTimeRange(start: cursor, duration: clipDuration)
            layerInstructions.append((placedRange, transform))

            cursor = CMTimeAdd(cursor, clipDuration)
        }

        let hasContent = cursor > .zero

        // 3) AVMutableVideoComposition 구성.
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        videoComposition.instructions = layerInstructions.map { entry in
            let inst = AVMutableVideoCompositionInstruction()
            inst.timeRange = entry.timeRange
            let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: compVideoTrack)
            layer.setTransform(entry.transform, at: entry.timeRange.start)
            inst.layerInstructions = [layer]
            return inst
        }

        return BuiltComposition(
            composition: composition,
            videoComposition: videoComposition,
            hasContent: hasContent
        )
    }

    // MARK: - RenderSize

    /// 첫 유효 클립의 displaySize에 사용자 회전을 적용한 사이즈를 출력 캔버스로 사용.
    /// displaySize 정보가 없는 경우는 기본 9:16 (1080×1920).
    static func resolveRenderSize(
        clips: [Clip],
        rotations: [Clip.ID: ClipRotation]
    ) async -> CGSize {
        let fallback = CGSize(width: 1080, height: 1920)
        for clip in clips {
            // 1순위: Clip.displaySize (PHAsset에서 추출됨)
            if let size = clip.displaySize, size.width > 0, size.height > 0 {
                let rot = rotations[clip.id] ?? .r0
                return rot.swapsAxes ? CGSize(width: size.height, height: size.width) : size
            }
            // 2순위: 트랙에서 직접 읽어내기 (displaySize 미저장 케이스 — Live Photo 등)
            if let url = clip.videoURL {
                let asset = AVURLAsset(url: url)
                if let track = (try? await asset.loadTracks(withMediaType: .video))?.first {
                    let natural = (try? await track.load(.naturalSize)) ?? .zero
                    let transform = (try? await track.load(.preferredTransform)) ?? .identity
                    let display = natural.applying(transform)
                    let w = abs(display.width)
                    let h = abs(display.height)
                    if w > 0, h > 0 {
                        let size = CGSize(width: w, height: h)
                        let rot = rotations[clip.id] ?? .r0
                        return rot.swapsAxes ? CGSize(width: size.height, height: size.width) : size
                    }
                }
            }
        }
        return fallback
    }

    // MARK: - Transform helper

    /// 한 클립이 renderSize 안에서 가운데 정렬되도록 하는 affine transform.
    /// = preferredTransform × userRotation × translate(가운데로).
    /// 회전 후 사이즈가 renderSize보다 크거나 작아도 가운데 정렬 — fit/letterbox 처리.
    static func transform(
        naturalSize: CGSize,
        preferredTransform: CGAffineTransform,
        rotation: ClipRotation,
        renderSize: CGSize
    ) -> CGAffineTransform {
        // preferredTransform 적용 후 displaySize.
        let displayRect = CGRect(origin: .zero, size: naturalSize).applying(preferredTransform)
        let displaySize = CGSize(width: abs(displayRect.width), height: abs(displayRect.height))

        // 사용자 회전 후 displaySize.
        let postRotationSize: CGSize = rotation.swapsAxes
            ? CGSize(width: displaySize.height, height: displaySize.width)
            : displaySize

        // 가운데 정렬 translate.
        let centerOffset = CGPoint(
            x: (renderSize.width - postRotationSize.width) / 2,
            y: (renderSize.height - postRotationSize.height) / 2
        )

        // 합성 순서:
        //   1) preferredTransform 적용된 좌표는 음수 영역에 있을 수 있어 (0,0)으로 끌어올리는 평행이동
        //   2) 회전(원점 기준 rotate + 회전 후 음수 영역을 다시 (0,0)으로 끌어올리는 평행이동)
        //   3) 가운데로 translate
        let normalizeAfterPreferred = CGAffineTransform(
            translationX: -displayRect.minX,
            y: -displayRect.minY
        )

        // 사용자 회전 적용. rotation을 (0,0) 기준에서 돌리면 사분면 밖으로 나가므로
        // 다시 (0,0)으로 끌어올리는 보정을 더한다.
        let rotationMatrix = rotation.transform
        let rotatedRect = CGRect(origin: .zero, size: displaySize).applying(rotationMatrix)
        let rotationNormalize = CGAffineTransform(
            translationX: -rotatedRect.minX,
            y: -rotatedRect.minY
        )

        let centerTranslate = CGAffineTransform(
            translationX: centerOffset.x,
            y: centerOffset.y
        )

        // 적용 순서: 좌측에 곱한 행렬이 먼저 적용됨 (CGAffineTransform.concatenating(_) 의미).
        // 우리는 결과 = centerTranslate ∘ rotationNormalize ∘ rotation ∘ normalizeAfterPreferred ∘ preferredTransform 을
        // "벡터 v에 대해 preferredTransform 먼저 적용 → ... → centerTranslate 마지막 적용"으로 읽고 싶다.
        // CGAffineTransform.concatenating(b) 은 self * b 라서, a.concatenating(b) = b ∘ a
        // 즉 점에 a를 먼저, b를 나중에 적용. 따라서 아래처럼 누적한다.
        return preferredTransform
            .concatenating(normalizeAfterPreferred)
            .concatenating(rotationMatrix)
            .concatenating(rotationNormalize)
            .concatenating(centerTranslate)
    }

    // MARK: - Output URL

    private static func makeOutputURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("moments-\(UUID().uuidString).mp4")
    }
}
