import Foundation
import Models
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
                while !Task.isCancelled {
                    let progress = Double(session.progress)
                    if progress.isFinite {
                        continuation.yield(.progress(min(max(progress, 0), 0.99)))
                    }
                    try? await Task.sleep(nanoseconds: 150_000_000)
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
        var compAudioTrack: AVMutableCompositionTrack?

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

            let desiredSeconds = max(clip.duration, 0.5)
            let requestedDuration = CMTime(seconds: desiredSeconds, preferredTimescale: 600)
            let clipDuration = CMTimeMinimum(requestedDuration, assetDuration)
            let timeRange = CMTimeRange(start: .zero, duration: clipDuration)

            do {
                try compVideoTrack.insertTimeRange(timeRange, of: assetVideoTrack, at: cursor)
            } catch {
                continue
            }

            if let assetAudioTrack = (try? await asset.loadTracks(withMediaType: .audio))?.first {
                if compAudioTrack == nil {
                    compAudioTrack = composition.addMutableTrack(
                        withMediaType: .audio,
                        preferredTrackID: kCMPersistentTrackID_Invalid
                    )
                }
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

    /// 모든 클립의 effectiveSize에 사용자 회전을 적용한 뒤 면적이 가장 큰 클립을 출력 캔버스로 사용.
    /// 동률은 첫 등장 우선. 모두 사이즈 추출 실패 시 기본 9:16 (1080×1920).
    public static func resolveRenderSize(
        clips: [Clip],
        rotations: [Clip.ID: ClipRotation]
    ) async -> CGSize {
        let fallback = CGSize(width: 1080, height: 1920)
        var best: CGSize? = nil
        var bestArea: CGFloat = 0

        for clip in clips {
            guard let raw = await effectiveSize(for: clip) else { continue }
            let rot = rotations[clip.id] ?? .r0
            let oriented = rot.swapsAxes
                ? CGSize(width: raw.height, height: raw.width)
                : raw
            let area = oriented.width * oriented.height
            if area > bestArea {                  // 동률은 갱신 안 함 → 첫 등장 우선
                bestArea = area
                best = oriented
            }
        }
        return best ?? fallback
    }

    /// 한 클립의 "preferredTransform 적용 후 displaySize"를 계산.
    /// 1순위: Clip.displaySize (PHAsset에서 추출됨), 2순위: AVAsset 트랙에서 직접 로드.
    /// 둘 다 실패하면 nil. width/height가 0 이하면 무효 처리.
    private static func effectiveSize(for clip: Clip) async -> CGSize? {
        if let size = clip.displaySize, size.width > 0, size.height > 0 {
            return size
        }
        if let url = clip.videoURL {
            let asset = AVURLAsset(url: url)
            if let track = (try? await asset.loadTracks(withMediaType: .video))?.first {
                let natural = (try? await track.load(.naturalSize)) ?? .zero
                let transform = (try? await track.load(.preferredTransform)) ?? .identity
                let display = natural.applying(transform)
                let w = abs(display.width)
                let h = abs(display.height)
                if w > 0, h > 0 {
                    return CGSize(width: w, height: h)
                }
            }
        }
        return nil
    }

    // MARK: - Transform helper

    private static let minDisplayDimension: CGFloat = 1.0

    /// 한 클립이 renderSize 안에서 비율 유지된 채 최대 크기로 fit되어 가운데 정렬되도록 하는 affine transform.
    /// 비율이 다르면 한 축에만 letterbox.
    public static func transform(
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

        // 합성 순서:
        //   1) preferredTransform 적용된 좌표는 음수 영역에 있을 수 있어 (0,0)으로 끌어올리는 평행이동
        //   2) 회전(원점 기준 rotate + 회전 후 음수 영역을 다시 (0,0)으로 끌어올리는 평행이동)
        //   3) aspectFit scale (rotationNormalize 후 (0,0)–postRotationSize에 정렬된 사각형을 비율유지로 확대/축소)
        //   4) scaledSize 기준 가운데 translate (한 축은 꽉, 다른 축은 letterbox)
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

        // aspectFit scale. 0 또는 NaN/Inf 가드.
        let safeW = max(postRotationSize.width,  Self.minDisplayDimension)
        let safeH = max(postRotationSize.height, Self.minDisplayDimension)
        let fitScaleRaw = min(renderSize.width / safeW, renderSize.height / safeH)
        let fitScale: CGFloat = (fitScaleRaw.isFinite && fitScaleRaw > 0) ? fitScaleRaw : 1.0

        let scaledSize = CGSize(
            width: postRotationSize.width * fitScale,
            height: postRotationSize.height * fitScale
        )
        let scaleMatrix = CGAffineTransform(scaleX: fitScale, y: fitScale)

        let centerTranslate = CGAffineTransform(
            translationX: (renderSize.width - scaledSize.width) / 2,
            y: (renderSize.height - scaledSize.height) / 2
        )

        // 적용 순서: 좌측에 곱한 행렬이 먼저 적용됨 (CGAffineTransform.concatenating(_) 의미).
        // CGAffineTransform.concatenating(b) 은 self * b 라서, a.concatenating(b) = b ∘ a
        // 즉 점에 a를 먼저, b를 나중에 적용. 따라서 아래처럼 누적한다.
        return preferredTransform
            .concatenating(normalizeAfterPreferred)
            .concatenating(rotationMatrix)
            .concatenating(rotationNormalize)
            .concatenating(scaleMatrix)
            .concatenating(centerTranslate)
    }

    // MARK: - Output URL

    private static func makeOutputURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("moments-\(UUID().uuidString).mp4")
    }
}
