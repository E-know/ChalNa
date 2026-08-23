import Foundation
import Models
import AVFoundation
import CoreGraphics
import QuartzCore
import CoreImage
#if canImport(UIKit)
import UIKit
#endif

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
            return String(localized: "합성 가능한 영상이 없어요. 영상 또는 Live Photo를 골라주세요.")
        case .sessionSetupFailed:
            return String(localized: "내보내기 세션을 준비하지 못했어요.")
        case .trackCreationFailed:
            return String(localized: "비디오 트랙을 만들 수 없어요.")
        case .exportFailed(let msg):
            return String(localized: "저장 중 문제가 생겼어요: \(msg)")
        }
    }
}

public protocol CompositionServicing: Sendable {
    /// 클립 배열·회전·클립별 변환·클립별 사용자 라벨을 받아 mp4를 만든다.
    /// 자동 시각/날짜 라벨은 설정 대상이 아니라 항상 붙는다 — 기하·불투명도는 `LabelLayout` 고정값.
    func export(
        clips: [Clip],
        rotations: [Clip.ID: ClipRotation],
        transforms: [Clip.ID: ClipTransform],
        clipLabels: [Clip.ID: ClipLabel]
    ) -> AsyncStream<ExportEvent>
}

public extension CompositionServicing {
    /// 사용자 라벨 없는 호출 → 빈 라벨(현행 동작).
    func export(clips: [Clip], rotations: [Clip.ID: ClipRotation]) -> AsyncStream<ExportEvent> {
        export(clips: clips, rotations: rotations, transforms: [:], clipLabels: [:])
    }
    /// 회전 없는 호출.
    func export(clips: [Clip]) -> AsyncStream<ExportEvent> {
        export(clips: clips, rotations: [:], transforms: [:], clipLabels: [:])
    }
}

/// AVFoundation 기반 실 구현체. PhotosPicker에서 받아온 videoURL들을 이어 붙여 mp4로 내보낸다.
public actor AVFoundationCompositionService: CompositionServicing {
    public init() {}

    /// 외부에서 부르는 유일한 진입점. actor 메서드인데 `nonisolated` — actor 잠금을
    /// 기다리지 않고 즉시 실행된다. "이벤트가 흘러나올 통로(AsyncStream)"만 곧바로 만들어
    /// 돌려주고, 실제 무거운 작업은 그 안쪽 Task에서 비동기로 시작한다.
    public nonisolated func export(
        clips: [Clip],                          // 이어붙일 클립들(이미 촬영순 정렬)
        rotations: [Clip.ID: ClipRotation],     // 클립별 사용자 회전(없으면 0°)
        transforms: [Clip.ID: ClipTransform],   // 클립별 확대·이동(없으면 .fill = 센터 크롭)
        clipLabels: [Clip.ID: ClipLabel]        // 클립별 사용자 자막
    ) -> AsyncStream<ExportEvent> {             // 반환값 = 이벤트가 흘러나오는 통로
        AsyncStream { continuation in
            // continuation = 이 통로에 이벤트를 밀어 넣는 손잡이.
            let task = Task { [weak self] in    // 실제 작업은 백그라운드 Task에서.
                guard let self else {
                    continuation.finish()
                    return
                }
                // 여기서부터 actor 격리 안. run()이 전 과정을 진행하며
                // continuation으로 .progress / .completed / .failed 를 흘려보낸다.
                await self.run(clips: clips, rotations: rotations, transforms: transforms, clipLabels: clipLabels, continuation: continuation)
            }
            // 구독자가 통로를 버리면(화면 이탈 등) 굽기 Task도 취소된다.
            // 안 보이는 영상을 계속 굽느라 배터리·발열을 낭비하지 않기 위함.
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Pipeline

    /// 전체 파이프라인을 지휘하는 곳. 재료 준비 → 세션 준비 → 진행률 폴링 →
    /// 굽기 → 이벤트 발행 → 에러 처리까지 한 흐름으로 진행한다.
    private func run(
        clips: [Clip],
        rotations: [Clip.ID: ClipRotation],
        transforms: [Clip.ID: ClipTransform],
        clipLabels: [Clip.ID: ClipLabel],
        continuation: AsyncStream<ExportEvent>.Continuation
    ) async {
        do {
            // [1·2·3단계] 트랙 잇기 + 클립별 변환·라벨 instruction 만들기.
            let built = try await buildComposition(clips: clips, rotations: rotations, transforms: transforms, clipLabels: clipLabels)
            guard built.hasContent else {
                throw ExportError.noVideoClips   // 한 장도 못 붙였으면 중단.
            }

            let outputURL = Self.makeOutputURL()                // 임시폴더/chalNa-<UUID>.mp4
            try? FileManager.default.removeItem(at: outputURL)  // 남은 동명 파일 정리.

            // [5단계] 굽는 기계 준비 — 최고 화질 프리셋.
            guard let session = AVAssetExportSession(
                asset: built.composition,
                presetName: AVAssetExportPresetHighestQuality
            ) else {
                throw ExportError.sessionSetupFailed
            }
            session.shouldOptimizeForNetworkUse = true          // 재생 시작 빠르게(moov atom 앞으로).
            session.videoComposition = built.videoComposition   // 우리 플레이팅 방법(커스텀 컴포지터)을 등록.

            // 진행률 관찰은 별도 Task로 동시 진행 — 0.15초마다 session.progress 를 폴링.
            let progressTask = Task { [session] in
                while !Task.isCancelled {
                    let progress = Double(session.progress)
                    if progress.isFinite {
                        // 0.99로 캡 — "다 됐다"고 먼저 말해놓고 파일이 아직 없는 상태를 막는다.
                        continuation.yield(.progress(min(max(progress, 0), 0.99)))
                    }
                    try? await Task.sleep(nanoseconds: 150_000_000)   // 150ms
                }
            }

            do {
                try await session.export(to: outputURL, as: .mp4)     // iOS 18 async 굽기.
                progressTask.cancel()
            } catch {
                progressTask.cancel()
                throw ExportError.exportFailed(error.localizedDescription)
            }

            continuation.yield(.progress(1.0))          // 진짜 끝났을 때만 100%.
            continuation.yield(.completed(outputURL))   // 완성 파일 위치 전달.
        } catch let err as ExportError {
            // 도메인 에러든 그 외 에러든, 사용자에겐 한국어 메시지 하나(.failed)로만 수렴시킨다.
            continuation.yield(.failed(err.errorDescription ?? String(localized: "알 수 없는 오류")))
        } catch {
            continuation.yield(.failed(error.localizedDescription))
        }
        continuation.finish()   // 성공이든 실패든 마지막엔 반드시 통로를 닫는다.
    }

    // MARK: - Build

    private struct BuiltComposition {
        let composition: AVMutableComposition
        let videoComposition: AVMutableVideoComposition
        let hasContent: Bool
    }

    /// [1·2·3단계] 클립을 한 트랙에 시간순으로 이어 붙이며(1단계), 클립마다 배치 변환
    /// (센터 크롭, 2단계)과 라벨 도장(3단계)을 준비하고, 우리만의 VideoComposition을 조립한다.
    private func buildComposition(
        clips: [Clip],
        rotations: [Clip.ID: ClipRotation],
        transforms: [Clip.ID: ClipTransform],
        clipLabels: [Clip.ID: ClipLabel]
    ) async throws -> BuiltComposition {
        // [1단계] 빈 필름 릴 + 비디오 트랙 1줄.
        let composition = AVMutableComposition()
        guard let compVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw ExportError.trackCreationFailed
        }
        var compAudioTrack: AVMutableCompositionTrack?   // 오디오는 첫 소리를 만날 때 lazy 생성.

        // 1) 출력 캔버스는 항상 outputSize(9:16, 1080×1920) 고정.
        //    비율이 다른 클립은 `transform()`이 aspectFill + 가운데 정렬(센터 크롭)로 캔버스를 꽉 채운다.
        let renderSize = await Self.resolveRenderSize(clips: clips, rotations: rotations)

        // 2) 시간순으로 트랙을 채우면서 클립별 layerInstruction 누적.
        //    cursor = "지금까지 채운 시간"(빨래집게). 클립 하나 붙일 때마다 그 길이만큼 전진.
        var cursor = CMTime.zero
        var layerInstructions: [(timeRange: CMTimeRange, transform: CGAffineTransform, capturedAt: Date, clipID: Clip.ID)] = []

        for clip in clips {
            guard let videoURL = clip.videoURL else { continue }   // 영상 없는 클립은 스킵.
            let asset = AVURLAsset(url: videoURL)
            let videoTracks = (try? await asset.loadTracks(withMediaType: .video)) ?? []
            guard let assetVideoTrack = videoTracks.first else { continue }

            // 사용 길이 = min( max(원하는 길이, 0.5초), 원본 길이 ). 길이 0/비정상 클립은 스킵.
            let assetDuration = (try? await asset.load(.duration)) ?? .zero
            let assetSeconds = CMTimeGetSeconds(assetDuration)
            guard assetSeconds.isFinite, assetSeconds > 0 else { continue }

            let desiredSeconds = max(clip.duration, 0.5)
            let requestedDuration = CMTime(seconds: desiredSeconds, preferredTimescale: 600)  // 600 = 비디오 표준 타임스케일.
            let clipDuration = CMTimeMinimum(requestedDuration, assetDuration)
            let timeRange = CMTimeRange(start: .zero, duration: clipDuration)

            // 비디오를 cursor 위치에 이어 붙이기(삽입 실패하면 그 클립만 건너뛴다 — 관대한 스킵).
            do {
                try compVideoTrack.insertTimeRange(timeRange, of: assetVideoTrack, at: cursor)
            } catch {
                continue
            }

            // 소리가 있으면 같은 위치에 오디오도 붙여 싱크 유지(오디오 트랙은 첫 소리 때 한 번만 생성).
            if let assetAudioTrack = (try? await asset.loadTracks(withMediaType: .audio))?.first {
                if compAudioTrack == nil {
                    compAudioTrack = composition.addMutableTrack(
                        withMediaType: .audio,
                        preferredTrackID: kCMPersistentTrackID_Invalid
                    )
                }
                try? compAudioTrack?.insertTimeRange(timeRange, of: assetAudioTrack, at: cursor)
            }

            // [2단계] 트랙 메타로 이 클립의 배치 변환 2개를 계산.
            // preferredTransform = 카메라가 남긴 "누운 영상 세우기" 회전 메모. 모든 크기 계산의 기준.
            let preferredTransform = (try? await assetVideoTrack.load(.preferredTransform)) ?? .identity
            let naturalSize = (try? await assetVideoTrack.load(.naturalSize)) ?? renderSize
            let userRotation = rotations[clip.id] ?? .r0

            // 전경: aspectFill(센터 크롭) + 사용자 확대·이동. 캔버스를 항상 꽉 덮는다.
            let transform = Self.transform(
                naturalSize: naturalSize,
                preferredTransform: preferredTransform,
                rotation: userRotation,
                renderSize: renderSize,
                framing: transforms[clip.id] ?? .fill
            )

            // 한 클립 구간의 합성 재료를 모아둔다(컴포지터가 나중에 읽음).
            let placedRange = CMTimeRange(start: cursor, duration: clipDuration)
            layerInstructions.append((placedRange, transform, clip.capturedAt, clip.id))

            cursor = CMTimeAdd(cursor, clipDuration)   // 집게를 오른쪽으로 전진.
        }

        let hasContent = cursor > .zero   // 한 장이라도 붙었나? 아니면 run()이 noVideoClips 로 중단.

        // 3) [3·4단계] AVMutableVideoComposition 구성. 전경이 캔버스를 꽉 덮으므로(센터 크롭)
        //    커스텀 컴포지터(`ChalNaVideoCompositor`)는 전경 배치 + 라벨 합성만 담당한다.
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)          // 출력 30fps (바로 이 한 줄).
        videoComposition.customVideoCompositorClass = ChalNaVideoCompositor.self  // 우리 플레이팅 담당을 끼운다.
        // 같은 "시각 문자열 + 날짜 문자열 + 자막" 조합은 완전히 같은 그림이다. 한 편의 vlog 는
        // 같은 분(分)에 찍힌 클립이 흔해서 이 캐시가 실제로 듣는다 — 그림 하나를 여러 instruction 이
        // 공유하면 그만큼 동시 생존 비트맵이 준다. 이 딕셔너리는 buildComposition 호출 범위에서만 산다.
        var overlayCache: [OverlayKey: (image: CGImage, origin: CGPoint)] = [:]

        videoComposition.instructions = layerInstructions.map { entry in
            // 클립별 라벨(시간/날짜/커스텀)을 정적 CGImage 로 미리 렌더해 컴포지터가 전경 위에 합성.
            // 라벨은 구간 내내 안 움직이므로 "도장"처럼 한 번만 그려 둔다.
            var overlay: (image: CGImage, origin: CGPoint)?
            #if canImport(UIKit)
            let clipLabel = clipLabels[entry.clipID] ?? .default
            let locale = LabelText.locale()
            let key = OverlayKey(
                time: LabelText.timeString(entry.capturedAt, locale: locale),
                date: LabelText.dateString(entry.capturedAt, locale: locale),
                label: clipLabel
            )
            if let cached = overlayCache[key] {
                overlay = cached
            } else {
                overlay = Self.renderLabelOverlayImage(
                    renderSize: renderSize,
                    capturedAt: entry.capturedAt,
                    clipLabel: clipLabel
                )
                overlayCache[key] = overlay
            }
            #endif
            // 한 클립 구간의 "합성 설명서"를 만들어 넘긴다(전경 변환·라벨).
            return ChalNaCompositionInstruction(
                timeRange: entry.timeRange,
                trackID: compVideoTrack.trackID,
                foreground: entry.transform,
                overlayImage: overlay?.image,
                overlayOrigin: overlay?.origin ?? .zero
            )
        }

        return BuiltComposition(
            composition: composition,
            videoComposition: videoComposition,
            hasContent: hasContent
        )
    }

    // MARK: - Date label overlay

    // 로케일 해석과 시각/날짜 포매터는 `Models.LabelText` 가 갖는다 —
    // 미리보기(`AutoLabelsOverlay`)와 여기가 같은 문자열을 만들어야 WYSIWYG 가 맞는데,
    // 예전엔 양쪽에 그대로 복제해 두고 주석으로만 동기화하고 있었다.

    #if canImport(UIKit)
    /// 한 클립 구간의 라벨(시간/날짜/커스텀)을 `renderSize` 의 투명 CALayer 트리로 쌓아 정적 CGImage 로 렌더한다.
    ///
    /// 시각·날짜는 **항상 그려진다**(사용자가 끌 수 없다) — 따라서 "라벨이 없어서 nil" 인 경우는
    /// 없고, nil 은 비트맵 생성 실패뿐이다. 스킵 경로에 기대는 호출자를 만들지 말 것.
    /// 대신 같은 그림이 반복되는 비용은 `buildComposition` 의 오버레이 캐시가 막는다.
    ///
    /// 좌표계: 라벨 origin 들은 CoreAnimation y-UP(좌하단 원점)으로 계산된다. 이를 top-left 원점
    /// CGContext 로 렌더하면 상하가 뒤집히므로 `parentLayer.isGeometryFlipped = true` 로 보정한다
    /// → y-up 으로 계산한 TOP 라벨이 이미지 위쪽에 실제로 그려진다.
    private static func renderLabelOverlayImage(
        renderSize: CGSize,
        capturedAt: Date,
        clipLabel: ClipLabel
    ) -> (image: CGImage, origin: CGPoint)? {
        let minDim = min(renderSize.width, renderSize.height)
        let dateFontSize = minDim * LabelLayout.dateFontFraction
        let timeFontSize = minDim * LabelLayout.timeFontFraction
        let padding = CGSize(width: renderSize.width * LabelLayout.paddingFraction, height: renderSize.height * LabelLayout.paddingFraction)
        let stackGap = minDim * LabelLayout.stackGapFraction

        let locale = LabelText.locale()
        let dateText = LabelText.dateString(capturedAt, locale: locale)
        let timeText = LabelText.timeString(capturedAt, locale: locale)

        // 위치는 우측 하단 고정. 시각을 날짜 위로 쌓고 둘 다 항상 그린다.
        let timeSize = LabelText.measure(timeText, px: timeFontSize)
        let dateSize = LabelText.measure(dateText, px: dateFontSize)
        let origins = LabelLayout.stackedOrigins(
            timeSize: timeSize,
            dateSize: dateSize,
            gap: stackGap,
            renderSize: renderSize,
            padding: padding
        )

        // 레이어 frame 은 전부 **캔버스 기준 y-up(좌하단 원점)** 으로 잡는다.
        var layers: [CALayer] = [
            makeOverlayTextLayer(text: dateText, fontSize: dateFontSize) { _ in origins.date },
            makeOverlayTextLayer(text: timeText, fontSize: timeFontSize) { _ in origins.time },
        ]
        if clipLabel.isVisible {
            // 자막 앵커는 크롭 상태와 무관하게 항상 캔버스 전체 기준이다 — placedRect 를
            // 늘 origin .zero, size renderSize(캔버스 전체)로 넘기기 때문이다(자유 크롭으로
            // 전경이 캔버스보다 작아져도 앵커는 그대로 캔버스 코너에 고정된다).
            layers += makeCustomLabelLayers(
                label: clipLabel, placedRect: CGRect(origin: .zero, size: renderSize), renderSize: renderSize
            )
        }

        // 라벨이 실제로 덮는 사각형만 렌더한다. 캔버스 전체(1080×1920 RGBA ≈ 8MB)를 클립마다
        // 만들면 instructions 가 그걸 전부 붙들고 있어 30클립 vlog 가 ≈240MB 를 export 내내 유지한다.
        // 코너 스탬프만 있는 일반적인 경우 이 박스는 ≈200×121 (≈97KB) 로 두 자릿수 배 작다.
        guard let cropRect = stampBounds(of: layers, renderSize: renderSize) else { return nil }

        // 서브렉트를 새 캔버스로 삼아 레이어 좌표를 평행이동한다.
        // **컨텍스트를 translate 하면 안 된다** — `isGeometryFlipped` 의 뒤집기 기준이
        // 레이어 bounds 가 아니라 그리기 컨텍스트를 따라가면서 전체가 화면 밖으로 나간다
        // (실측: 서브렉트 컨텍스트 + CTM translate 조합은 완전히 빈 이미지를 만들었다).
        // 좌표를 옮기면 원본과 같은 코드 경로 위에서 캔버스만 작아진다.
        let yUpBottom = renderSize.height - cropRect.maxY
        for layer in layers {
            layer.frame = layer.frame.offsetBy(dx: -cropRect.minX, dy: -yUpBottom)
        }

        let parentLayer = CALayer()
        parentLayer.frame = CGRect(origin: .zero, size: cropRect.size)
        parentLayer.backgroundColor = UIColor.clear.cgColor
        layers.forEach { parentLayer.addSublayer($0) }

        // 라벨 origin 은 CoreAnimation y-UP(좌하단). `isGeometryFlipped = true` 로 하면
        // sublayer 좌표가 시각상 올바르게(상단=상단) 그려지면서 글자 자체는 뒤집히지 않는다.
        // → 결과 CGImage 는 "정상 방향(top-left)" 스크린샷. 이후 컴포지터가 전경과 동일하게 다룬다.
        parentLayer.isGeometryFlipped = true

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: cropRect.size, format: format)
        let uiImage = renderer.image { ctx in
            parentLayer.render(in: ctx.cgContext)
        }
        guard let cg = uiImage.cgImage else { return nil }
        return (cg, cropRect.origin)
    }

    /// 라벨 레이어들이 최종 이미지에서 덮는 영역(**top-left 원점**, 그림자 여유 포함, 캔버스로 클램프).
    ///
    /// 레이어 `frame` 은 y-up(좌하단) 으로 작성돼 있고 `isGeometryFlipped` 가 렌더 시점에
    /// 뒤집으므로, top-left 로 환산할 때 `renderH - maxY` 를 쓴다 —
    /// `LabelText.stampRect` 가 테스트용으로 하는 환산과 같은 규칙이다.
    private static func stampBounds(of layers: [CALayer], renderSize: CGSize) -> CGRect? {
        guard !layers.isEmpty else { return nil }
        let union = layers.reduce(CGRect.null) { acc, layer in
            let f = layer.frame
            return acc.union(CGRect(x: f.minX, y: renderSize.height - f.maxY, width: f.width, height: f.height))
        }
        guard !union.isNull else { return nil }
        let padded = union.insetBy(dx: -LabelText.shadowSlack, dy: -LabelText.shadowSlack).integral
        let clamped = padded.intersection(CGRect(origin: .zero, size: renderSize))
        return clamped.isEmpty ? nil : clamped
    }

    #endif

    /// 흰색 시스템 bold 텍스트에 검은 그림자를 입혀 만든 `CATextLayer`.
    /// `placement` 클로저는 실측 텍스트 사이즈를 받아 좌하단 원점(CoreAnimation) 기준 좌측 하단 좌표를 반환한다.
    /// 불투명도는 `LabelLayout.opacity` 로 고정한다(클립 구간 동안만 컴포지터가 합성하므로 per-frame gating 불필요).
    private static func makeOverlayTextLayer(
        text: String,
        fontSize: CGFloat,
        placement: (CGSize) -> CGPoint
    ) -> CATextLayer {
        let textLayer = CATextLayer()
        let textSize = LabelText.measure(text, px: fontSize)

        // CATextLayer.font 에 CGFont 를 직접 할당하는 패턴은 Swift에서 wrapping 이슈로
        // 무시되는 사례가 있어, NSAttributedString의 .font attribute 로 적용한다.
        #if canImport(UIKit)
        textLayer.string = NSAttributedString(
            string: text,
            attributes: [
                .font: LabelText.uiFont(px: fontSize),
                .foregroundColor: UIColor.white,
            ]
        )
        #else
        textLayer.string = text
        textLayer.fontSize = fontSize
        #endif

        textLayer.contentsScale = 2.0
        textLayer.isWrapped = false
        // CoreAnimation 좌표계는 좌하단 원점. 아래쪽으로 떨어지는 그림자는 -y 오프셋.
        textLayer.shadowColor = CGColor(red: 0, green: 0, blue: 0, alpha: 1)
        textLayer.shadowOpacity = 0.5
        textLayer.shadowOffset = CGSize(width: 0, height: -2)
        textLayer.shadowRadius = 4

        let origin = placement(textSize)
        textLayer.frame = CGRect(origin: origin, size: textSize)
        textLayer.opacity = Float(LabelLayout.opacity)

        return textLayer
    }

    #if canImport(UIKit)
    /// 박스 자막 라벨용 UIFont — 시스템 light 고정.
    private static func overlayCustomUIFont(fontSize: CGFloat) -> UIFont {
        .systemFont(ofSize: fontSize, weight: .light)
    }

    /// 박스 자막 텍스트 실측(시스템 light + 자간 기준).
    private static func measureCustomText(_ text: String, fontSize: CGFloat) -> CGSize {
        let attributed = NSAttributedString(
            string: text,
            attributes: [
                .font: overlayCustomUIFont(fontSize: fontSize),
                .kern: ClipLabel.BoxStyle.letterSpacing(for: fontSize),
            ]
        )
        let m = attributed.size()
        return CGSize(width: ceil(m.width), height: ceil(m.height))
    }

    /// 박스 자막 라벨 한 개를 그릴 레이어들.
    ///
    /// - `label.hasBackground == true`  → `[배경 박스, 텍스트]` (흰 면 · 검정 테두리 · 검정 글씨)
    /// - `label.hasBackground == false` → `[텍스트]` (흰 글씨, 장식 없음)
    ///
    /// **두 경우 `textLayer.frame` 은 동일하다** — 패딩을 유지하므로 토글이 위치를 움직이지 않는다.
    /// 프리뷰의 `BoxSubtitleStyle`/`ClipLabelBoxPalette` 가 같은 규칙·같은 색을 쓴다(WYSIWYG).
    /// `internal`(테스트 도달용) — `CustomLabelLayoutTests` 가 레이어 구성과 글자 프레임을 잠근다.
    static func makeCustomLabelLayers(
        label: ClipLabel,
        placedRect: CGRect,
        renderSize: CGSize
    ) -> [CALayer] {
        let fontSize = max(8, label.clampedSizeFraction * placedRect.height)
        let textSize = measureCustomText(label.text, fontSize: fontSize)
        let origin = customLabelOrigin(placedRect: placedRect, position: label.position, textSize: textSize, renderSize: renderSize)

        let textLayer = CATextLayer()
        textLayer.string = NSAttributedString(
            string: label.text,
            attributes: [
                .font: overlayCustomUIFont(fontSize: fontSize),
                // 흰 박스 위면 검정, 영상 위에 직접 올리면 흰색. 프리뷰의 ClipLabelBoxPalette 와 같은 규칙.
                .foregroundColor: label.hasBackground ? UIColor.black : UIColor.white,
                .kern: ClipLabel.BoxStyle.letterSpacing(for: fontSize),
            ]
        )
        textLayer.contentsScale = 2.0
        textLayer.isWrapped = false
        textLayer.alignmentMode = .center
        textLayer.frame = CGRect(origin: origin, size: textSize)
        textLayer.opacity = 1

        // 배경 OFF: 장식 없이 텍스트만. (패딩은 계산에 쓰지 않으므로 frame 은 위와 동일하게 유지된다.)
        guard label.hasBackground else { return [textLayer] }

        // 흰 배경 + 검정 테두리 박스. (프리뷰 ClipLabelText 와 동일한 ClipLabel.BoxStyle 사용)
        let padX = fontSize * ClipLabel.BoxStyle.horizontalPaddingFraction
        let padY = fontSize * ClipLabel.BoxStyle.verticalPaddingFraction
        let bgLayer = CALayer()
        bgLayer.frame = CGRect(
            x: origin.x - padX,
            y: origin.y - padY,
            width: textSize.width + padX * 2,
            height: textSize.height + padY * 2
        )
        bgLayer.backgroundColor = UIColor.white.cgColor
        bgLayer.borderColor = UIColor.black.cgColor
        bgLayer.borderWidth = fontSize * ClipLabel.BoxStyle.borderWidthFraction
        bgLayer.opacity = 1

        return [bgLayer, textLayer]
    }
    #endif

    // MARK: - RenderSize

    /// 최종 출력 캔버스 — 9:16 세로 고정.
    public static let outputSize = CGSize(width: 1080, height: 1920)

    /// 출력 캔버스는 입력 클립과 무관하게 항상 `outputSize`(1080×1920).
    /// 비율이 다른 클립은 `transform()` 이 aspectFill + 가운데 정렬(센터 크롭)로 캔버스를 꽉 채운다.
    /// (시그니처는 호출부 호환을 위해 유지)
    public static func resolveRenderSize(
        clips: [Clip],
        rotations: [Clip.ID: ClipRotation]
    ) async -> CGSize {
        outputSize
    }

    // MARK: - Transform helper

    /// 한 클립을 renderSize 에 aspectFill(=센터 크롭)로 배치하고, 사용자 변환(scale·offset)을 추가 적용한 affine transform.
    /// framing == .fill 이면 추가 조작 없는 기본 센터 크롭.
    /// scale·offset 에 제약은 없다 — 전경이 캔버스를 못 덮으면 남는 영역은 컴포지터의 검정 베이스가 받는다.
    public static func transform(
        naturalSize: CGSize,
        preferredTransform: CGAffineTransform,
        rotation: ClipRotation,
        renderSize: CGSize,
        framing: ClipTransform
    ) -> CGAffineTransform {
        // ① 회전 메모(preferredTransform)를 적용했을 때 영상이 실제로 보이는 사각형/크기.
        let displayRect = CGRect(origin: .zero, size: naturalSize).applying(preferredTransform)
        let displaySize = CGSize(width: abs(displayRect.width), height: abs(displayRect.height))
        let postRotationSize: CGSize = rotation.swapsAxes   // 90·270°면 가로·세로 swap.
            ? CGSize(width: displaySize.height, height: displaySize.width)
            : displaySize

        // ② preferredTransform이 원점을 음수로 밀었으면 (0,0)으로 당기는 보정.
        let normalizeAfterPreferred = CGAffineTransform(translationX: -displayRect.minX, y: -displayRect.minY)

        // ③ 사용자가 누른 회전 + 회전 후 원점 정리.
        let rotationMatrix = rotation.transform
        let rotatedRect = CGRect(origin: .zero, size: displaySize).applying(rotationMatrix)
        let rotationNormalize = CGAffineTransform(translationX: -rotatedRect.minX, y: -rotatedRect.minY)

        // ④ fill(센터 크롭) 배율은 ClipFraming 과 공유. 사용자 배율에는 UX 제약이 없고
        //    `sanitized` 의 산술 안전 가드([0.1, 10] + non-finite 방어)만 적용된다 —
        //    1 미만이면 캔버스에 검정 여백이 드러난다(컴포지터의 검정 베이스가 받는다).
        let safeFraming = framing.sanitized
        let fillScale = ClipFraming.fillScale(display: displaySize, rotation: rotation, render: renderSize)
        let totalScale = fillScale * safeFraming.scale

        let scaledSize = CGSize(width: postRotationSize.width * totalScale,
                                height: postRotationSize.height * totalScale)
        let scaleMatrix = CGAffineTransform(scaleX: totalScale, y: totalScale)
        // ⑤ 캔버스 한가운데로.
        let centerTranslate = CGAffineTransform(translationX: (renderSize.width - scaledSize.width) / 2,
                                                y: (renderSize.height - scaledSize.height) / 2)

        // ⑥ 사용자 이동(정규화 비율 → 픽셀). clamp 없음 — 전경이 캔버스 밖으로 나갈 수 있다.
        let offsetTranslate = CGAffineTransform(translationX: safeFraming.offset.x * renderSize.width,
                                                y: safeFraming.offset.y * renderSize.height)

        // 순서대로 곱한다 — 이 순서가 곧 의미(①보정 → ③회전 → ④배율 → ⑤중앙 → ⑥이동).
        return preferredTransform
            .concatenating(normalizeAfterPreferred)
            .concatenating(rotationMatrix)
            .concatenating(rotationNormalize)
            .concatenating(scaleMatrix)
            .concatenating(centerTranslate)
            .concatenating(offsetTranslate)
    }

    /// 클립 이미지 사각형 기준 정규화 위치(라벨 중심, y=위→아래)를
    /// CoreAnimation 좌하단 origin 으로 변환. 텍스트 박스의 좌측 하단 좌표를 돌려준다.
    public static func customLabelOrigin(
        placedRect: CGRect,
        position: CGPoint,
        textSize: CGSize,
        renderSize: CGSize
    ) -> CGPoint {
        let nx = min(max(position.x, 0), 1)
        let ny = min(max(position.y, 0), 1)
        let centerXTopDown = placedRect.minX + nx * placedRect.width
        let centerYTopDown = placedRect.minY + ny * placedRect.height
        let centerYUp = renderSize.height - centerYTopDown
        return CGPoint(x: centerXTopDown - textSize.width / 2, y: centerYUp - textSize.height / 2)
    }

    // MARK: - Output URL

    private static func makeOutputURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("chalNa-\(UUID().uuidString).mp4")
    }
}

/// 라벨 오버레이 비트맵의 내용 식별자. 이 셋이 같으면 렌더 결과가 픽셀 단위로 같다
/// (renderSize 는 한 export 안에서 고정이라 키에 넣지 않는다 — 캐시 수명이 `buildComposition`
/// 한 번의 호출로 한정되기 때문).
private struct OverlayKey: Hashable {
    let time: String
    let date: String
    let label: ClipLabel
}
