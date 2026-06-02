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
    /// 클립 배열·회전·클립별 변환·자동 라벨 설정·클립별 사용자 라벨을 받아 mp4를 만든다.
    func export(
        clips: [Clip],
        rotations: [Clip.ID: ClipRotation],
        transforms: [Clip.ID: ClipTransform],
        labelSettings: LabelSettings,
        clipLabels: [Clip.ID: ClipLabel]
    ) -> AsyncStream<ExportEvent>
}

public extension CompositionServicing {
    /// 사용자 라벨 없는 호출 → 빈 라벨(현행 동작).
    func export(clips: [Clip], rotations: [Clip.ID: ClipRotation], labelSettings: LabelSettings) -> AsyncStream<ExportEvent> {
        export(clips: clips, rotations: rotations, transforms: [:], labelSettings: labelSettings, clipLabels: [:])
    }
    /// 라벨 설정 없는 호출 → 기본값.
    func export(clips: [Clip], rotations: [Clip.ID: ClipRotation]) -> AsyncStream<ExportEvent> {
        export(clips: clips, rotations: rotations, transforms: [:], labelSettings: .default, clipLabels: [:])
    }
    /// 회전·라벨 설정 없는 호출.
    func export(clips: [Clip]) -> AsyncStream<ExportEvent> {
        export(clips: clips, rotations: [:], transforms: [:], labelSettings: .default, clipLabels: [:])
    }
}

/// AVFoundation 기반 실 구현체. PhotosPicker에서 받아온 videoURL들을 이어 붙여 mp4로 내보낸다.
public actor AVFoundationCompositionService: CompositionServicing {
    public init() {}

    public nonisolated func export(
        clips: [Clip],
        rotations: [Clip.ID: ClipRotation],
        transforms: [Clip.ID: ClipTransform],
        labelSettings: LabelSettings,
        clipLabels: [Clip.ID: ClipLabel]
    ) -> AsyncStream<ExportEvent> {
        AsyncStream { continuation in
            let task = Task { [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }
                await self.run(clips: clips, rotations: rotations, transforms: transforms, labelSettings: labelSettings, clipLabels: clipLabels, continuation: continuation)
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Pipeline

    private func run(
        clips: [Clip],
        rotations: [Clip.ID: ClipRotation],
        transforms: [Clip.ID: ClipTransform],
        labelSettings: LabelSettings,
        clipLabels: [Clip.ID: ClipLabel],
        continuation: AsyncStream<ExportEvent>.Continuation
    ) async {
        do {
            let built = try await buildComposition(clips: clips, rotations: rotations, transforms: transforms, labelSettings: labelSettings, clipLabels: clipLabels)
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
        rotations: [Clip.ID: ClipRotation],
        transforms: [Clip.ID: ClipTransform],
        labelSettings: LabelSettings,
        clipLabels: [Clip.ID: ClipLabel]
    ) async throws -> BuiltComposition {
        let composition = AVMutableComposition()
        guard let compVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw ExportError.trackCreationFailed
        }
        var compAudioTrack: AVMutableCompositionTrack?

        // 1) 출력 캔버스는 항상 outputSize(9:16, 1080×1920) 고정.
        //    비율이 다른 클립은 `transform()`이 aspectFit + 가운데 정렬해 letterbox/pillarbox 처리.
        let renderSize = await Self.resolveRenderSize(clips: clips, rotations: rotations)

        // 2) 시간순으로 트랙을 채우면서 클립별 layerInstruction 누적.
        var cursor = CMTime.zero
        var layerInstructions: [(timeRange: CMTimeRange, transform: CGAffineTransform, backgroundTransform: CGAffineTransform, capturedAt: Date, clipID: Clip.ID, placedRect: CGRect, thumbnailData: Data?)] = []

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
                renderSize: renderSize,
                framing: transforms[clip.id] ?? .fit
            )

            let backgroundTransform = Self.fillTransform(
                naturalSize: naturalSize,
                preferredTransform: preferredTransform,
                rotation: userRotation,
                renderSize: renderSize
            )

            let placedRange = CMTimeRange(start: cursor, duration: clipDuration)
            let pRect = Self.placedRect(
                naturalSize: naturalSize,
                preferredTransform: preferredTransform,
                rotation: userRotation,
                renderSize: renderSize
            )
            layerInstructions.append((placedRange, transform, backgroundTransform, clip.capturedAt, clip.id, pRect, clip.thumbnailData))

            cursor = CMTimeAdd(cursor, clipDuration)
        }

        let hasContent = cursor > .zero

        // 3) AVMutableVideoComposition 구성. 여백(letterbox)을 클립의 블러 필로 채우기 위해
        //    커스텀 컴포지터(`ChalNaVideoCompositor`)와 클립별 `ChalNaCompositionInstruction` 을 쓴다.
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        videoComposition.customVideoCompositorClass = ChalNaVideoCompositor.self
        let blurRadius = min(renderSize.width, renderSize.height) * 0.04
        videoComposition.instructions = layerInstructions.map { entry in
            // 클립별 라벨(시간/날짜/커스텀)을 정적 CGImage 로 미리 렌더해 컴포지터가 전경 위에 합성.
            var overlay: CGImage?
            #if canImport(UIKit)
            overlay = Self.renderLabelOverlayImage(
                renderSize: renderSize,
                capturedAt: entry.capturedAt,
                placedRect: entry.placedRect,
                labelSettings: labelSettings,
                clipLabel: clipLabels[entry.clipID] ?? .default
            )
            #endif
            return ChalNaCompositionInstruction(
                timeRange: entry.timeRange,
                trackID: compVideoTrack.trackID,
                foreground: entry.transform,
                background: entry.backgroundTransform,
                blurRadius: blurRadius,
                scrimAlpha: 0.18,
                overlayImage: overlay
            )
        }

        return BuiltComposition(
            composition: composition,
            videoComposition: videoComposition,
            hasContent: hasContent
        )
    }

    // MARK: - Date label overlay

    /// 우측 하단 작은 라벨용 — 날짜만 (`yyyy/MM/dd`).
    /// 사용자의 현재 타임존 · POSIX 로케일(ICU 의존 제거).
    private static let dateOnlyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy/MM/dd"
        return f
    }()

    /// 화면 정중앙 큰 라벨용 — 시:분 (`HH:mm`).
    private static let timeOnlyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "HH:mm"
        return f
    }()

    /// `UIAppFonts`로 등록된 KERISKEDU 패밀리에서 Line(outline) 변형의 PostScript name 우선 선택.
    /// 매칭 실패 시 빈 문자열 → `UIFont(name:size:)`가 nil 리턴 → 시스템 폰트로 fallback.
    /// 첫 호출 시 진단용 print 1회 — 사용자 환경에서 매칭이 안 될 때 family/name 을 확인할 수 있음.
    private static let kerisLabelFontName: String = {
        #if canImport(UIKit)
        let kerisFamilies = UIFont.familyNames.filter { $0.localizedCaseInsensitiveContains("KERIS") }
        print("[CompositionService] KERIS families: \(kerisFamilies)")
        for family in kerisFamilies {
            let names = UIFont.fontNames(forFamilyName: family)
            print("[CompositionService] family=\(family) names=\(names)")
            if let line = names.first(where: {
                let upper = $0.uppercased()
                return upper.contains("LINE") || upper.contains("OUTLINE")
                    || upper.hasSuffix("_LINE") || upper.hasSuffix("-LINE")
            }) {
                return line
            }
            if let any = names.first {
                return any
            }
        }
        #endif
        return ""
    }()

    /// 클립별 블러 배경(videoLayer 아래) + 촬영일시/커스텀 라벨(videoLayer 위)을 합성하는 `AVVideoCompositionCoreAnimationTool`.
    /// - 배경: 각 클립 썸네일을 블러+aspectFill 해 9:16 여백을 채움. 자기 timeRange 동안만 보인다.
    /// - 시각 `HH:mm`: 큰 글씨(minDim×0.18), opacity 0.5
    /// - 날짜 `yyyy/MM/dd`: 작은 글씨(minDim×0.035), opacity 1.0
    /// 라벨 표시 여부·위치는 `labelSettings`를 따른다. 각 라벨은 자신의 timeRange 동안만 보인다.
    /// 시각·날짜가 모두 켜져 있고 위치가 같으면 세로 스택(시각 위 / 날짜 아래)으로 묶어 배치한다.
    private static func makeBackdropAndLabelTool(
        renderSize: CGSize,
        entries: [(timeRange: CMTimeRange, capturedAt: Date, clipID: Clip.ID, placedRect: CGRect, thumbnailData: Data?)],
        labelSettings: LabelSettings,
        clipLabels: [Clip.ID: ClipLabel]
    ) -> AVVideoCompositionCoreAnimationTool {
        let parentLayer = CALayer()
        let videoLayer = CALayer()
        parentLayer.frame = CGRect(origin: .zero, size: renderSize)
        videoLayer.frame = parentLayer.frame
        parentLayer.addSublayer(videoLayer)

        #if canImport(UIKit)
        // 각 클립의 블러 배경을 videoLayer 아래에 깔고, 자기 timeRange 동안만 보이게 한다.
        for entry in entries {
            if let backdrop = makeBlurredBackdropLayer(thumbnailData: entry.thumbnailData, renderSize: renderSize, timeRange: entry.timeRange) {
                parentLayer.insertSublayer(backdrop, below: videoLayer)
            }
        }
        #endif

        let minDim = min(renderSize.width, renderSize.height)
        let dateFontSize = minDim * LabelLayout.dateFontFraction
        let timeFontSize = minDim * LabelLayout.timeFontFraction
        let padding = CGSize(width: renderSize.width * LabelLayout.paddingFraction, height: renderSize.height * LabelLayout.paddingFraction)
        let stackGap = minDim * LabelLayout.stackGapFraction
        // 둘 다 켜져 있고 같은 구역이면 겹치므로 세로 스택으로 묶는다.
        let stacked = labelSettings.timeEnabled && labelSettings.dateEnabled
            && labelSettings.timePosition == labelSettings.datePosition

        #if canImport(UIKit)
        // 자동 시간·날짜 레이어 추가 "뒤"에 호출 — 커스텀 라벨을 그 위에 얹는다.
        func addCustomLabel(for entry: (timeRange: CMTimeRange, capturedAt: Date, clipID: Clip.ID, placedRect: CGRect, thumbnailData: Data?)) {
            let custom = clipLabels[entry.clipID] ?? .default
            guard custom.isVisible else { return }
            for layer in makeCustomLabelLayers(
                label: custom,
                placedRect: entry.placedRect,
                renderSize: renderSize,
                timeRange: entry.timeRange
            ) {
                parentLayer.addSublayer(layer)
            }
        }
        #endif

        for entry in entries {
            let dateText = dateOnlyFormatter.string(from: entry.capturedAt)
            let timeText = timeOnlyFormatter.string(from: entry.capturedAt)

            if stacked {
                let timeSize = measureOverlayText(timeText, fontSize: timeFontSize)
                let dateSize = measureOverlayText(dateText, fontSize: dateFontSize)
                let origins = LabelLayout.stackedOrigins(
                    position: labelSettings.timePosition,
                    timeSize: timeSize,
                    dateSize: dateSize,
                    gap: stackGap,
                    renderSize: renderSize,
                    padding: padding
                )
                let dateLayer = makeOverlayTextLayer(
                    text: dateText,
                    fontSize: dateFontSize,
                    timeRange: entry.timeRange,
                    opacity: labelSettings.dateOpacity
                ) { _ in origins.date }
                parentLayer.addSublayer(dateLayer)

                let timeLayer = makeOverlayTextLayer(
                    text: timeText,
                    fontSize: timeFontSize,
                    timeRange: entry.timeRange,
                    opacity: labelSettings.timeOpacity
                ) { _ in origins.time }
                parentLayer.addSublayer(timeLayer)

                #if canImport(UIKit)
                addCustomLabel(for: entry)
                #endif
                continue
            }

            if labelSettings.dateEnabled {
                let dateLayer = makeOverlayTextLayer(
                    text: dateText,
                    fontSize: dateFontSize,
                    timeRange: entry.timeRange,
                    opacity: labelSettings.dateOpacity
                ) { size in
                    labelSettings.datePosition.origin(renderSize: renderSize, textSize: size, padding: padding)
                }
                parentLayer.addSublayer(dateLayer)
            }

            if labelSettings.timeEnabled {
                let timeLayer = makeOverlayTextLayer(
                    text: timeText,
                    fontSize: timeFontSize,
                    timeRange: entry.timeRange,
                    opacity: labelSettings.timeOpacity
                ) { size in
                    labelSettings.timePosition.origin(renderSize: renderSize, textSize: size, padding: padding)
                }
                parentLayer.addSublayer(timeLayer)
            }

            #if canImport(UIKit)
            addCustomLabel(for: entry)
            #endif
        }

        return AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: videoLayer,
            in: parentLayer
        )
    }

    #if canImport(UIKit)
    /// 한 클립 구간의 라벨(시간/날짜/커스텀)을 `renderSize` 의 투명 CALayer 트리로 쌓아 정적 CGImage 로 렌더한다.
    /// `makeBackdropAndLabelTool` 가 한 클립에 대해 추가하던 라벨 레이어와 동일한 레이아웃이되,
    /// show-animation 없이 목표 opacity 로 고정한다(이 이미지는 클립 구간 동안만 컴포지터가 합성하므로 gating 불필요).
    /// 라벨이 하나도 보이지 않으면 nil 을 반환해 컴포지터가 합성을 스킵하게 한다.
    ///
    /// 좌표계: 라벨 origin 들은 CoreAnimation y-UP(좌하단 원점)으로 계산된다. 이를 top-left 원점
    /// CGContext 로 렌더하면 상하가 뒤집히므로 `parentLayer.isGeometryFlipped = true` 로 보정한다
    /// → y-up 으로 계산한 TOP 라벨이 이미지 위쪽에 실제로 그려진다.
    private static func renderLabelOverlayImage(
        renderSize: CGSize,
        capturedAt: Date,
        placedRect: CGRect,
        labelSettings: LabelSettings,
        clipLabel: ClipLabel
    ) -> CGImage? {
        let custom = clipLabel
        let anyVisible = labelSettings.timeEnabled || labelSettings.dateEnabled || custom.isVisible
        guard anyVisible else { return nil }

        let parentLayer = CALayer()
        parentLayer.frame = CGRect(origin: .zero, size: renderSize)
        parentLayer.backgroundColor = UIColor.clear.cgColor

        let minDim = min(renderSize.width, renderSize.height)
        let dateFontSize = minDim * LabelLayout.dateFontFraction
        let timeFontSize = minDim * LabelLayout.timeFontFraction
        let padding = CGSize(width: renderSize.width * LabelLayout.paddingFraction, height: renderSize.height * LabelLayout.paddingFraction)
        let stackGap = minDim * LabelLayout.stackGapFraction
        let stacked = labelSettings.timeEnabled && labelSettings.dateEnabled
            && labelSettings.timePosition == labelSettings.datePosition

        let dateText = dateOnlyFormatter.string(from: capturedAt)
        let timeText = timeOnlyFormatter.string(from: capturedAt)
        // 정적 렌더라 timeRange 는 쓰이지 않지만 시그니처 호환용으로 zero 를 넘긴다.
        let dummyRange = CMTimeRange(start: .zero, duration: .zero)

        if stacked {
            let timeSize = measureOverlayText(timeText, fontSize: timeFontSize)
            let dateSize = measureOverlayText(dateText, fontSize: dateFontSize)
            let origins = LabelLayout.stackedOrigins(
                position: labelSettings.timePosition,
                timeSize: timeSize,
                dateSize: dateSize,
                gap: stackGap,
                renderSize: renderSize,
                padding: padding
            )
            parentLayer.addSublayer(makeOverlayTextLayer(
                text: dateText, fontSize: dateFontSize, timeRange: dummyRange,
                opacity: labelSettings.dateOpacity, staticRender: true
            ) { _ in origins.date })
            parentLayer.addSublayer(makeOverlayTextLayer(
                text: timeText, fontSize: timeFontSize, timeRange: dummyRange,
                opacity: labelSettings.timeOpacity, staticRender: true
            ) { _ in origins.time })
        } else {
            if labelSettings.dateEnabled {
                parentLayer.addSublayer(makeOverlayTextLayer(
                    text: dateText, fontSize: dateFontSize, timeRange: dummyRange,
                    opacity: labelSettings.dateOpacity, staticRender: true
                ) { size in
                    labelSettings.datePosition.origin(renderSize: renderSize, textSize: size, padding: padding)
                })
            }
            if labelSettings.timeEnabled {
                parentLayer.addSublayer(makeOverlayTextLayer(
                    text: timeText, fontSize: timeFontSize, timeRange: dummyRange,
                    opacity: labelSettings.timeOpacity, staticRender: true
                ) { size in
                    labelSettings.timePosition.origin(renderSize: renderSize, textSize: size, padding: padding)
                })
            }
        }

        if custom.isVisible {
            for layer in makeCustomLabelLayers(
                label: custom, placedRect: placedRect, renderSize: renderSize,
                timeRange: dummyRange, staticRender: true
            ) {
                parentLayer.addSublayer(layer)
            }
        }

        // 라벨 origin 은 CoreAnimation y-UP(좌하단). `isGeometryFlipped = true` 로 하면
        // sublayer 좌표가 시각상 올바르게(상단=상단) 그려지면서 글자 자체는 뒤집히지 않는다.
        // → 결과 CGImage 는 "정상 방향(top-left)" 스크린샷. 이후 컴포지터가 전경과 동일하게 다룬다.
        parentLayer.isGeometryFlipped = true

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: renderSize, format: format)
        let uiImage = renderer.image { ctx in
            parentLayer.render(in: ctx.cgContext)
        }
        return uiImage.cgImage
    }

    /// 오버레이 라벨용 UIFont. KERISKEDU(UIAppFonts 등록, PostScript name 매칭 성공 시)
    /// 커스텀 폰트, 실패하면 시스템 bold로 fallback.
    private static func overlayUIFont(fontSize: CGFloat) -> UIFont {
        if !kerisLabelFontName.isEmpty,
           let f = UIFont(name: kerisLabelFontName, size: fontSize) {
            return f
        }
        return .systemFont(ofSize: fontSize, weight: .bold)
    }
    #endif

    /// 오버레이 텍스트의 실측 사이즈. `makeOverlayTextLayer`와 동일한 폰트/측정 규칙을 공유한다.
    /// - UIKit: 위 폰트로 만든 NSAttributedString의 `.size()`를 `ceil`.
    /// - 비-UIKit(테스트): 실측 불가 → 글자 수 기반 대략치 `fontSize * max(count,5)` × `fontSize*1.4`.
    private static func measureOverlayText(_ text: String, fontSize: CGFloat) -> CGSize {
        #if canImport(UIKit)
        let attributed = NSAttributedString(
            string: text,
            attributes: [.font: overlayUIFont(fontSize: fontSize)]
        )
        let measured = attributed.size()
        return CGSize(width: ceil(measured.width), height: ceil(measured.height))
        #else
        return CGSize(
            width: fontSize * CGFloat(max(text.count, 5)),
            height: fontSize * 1.4
        )
        #endif
    }

    /// 흰색 KERISKEDU(없으면 시스템 bold) 텍스트에 검은 그림자를 입혀 만든 `CATextLayer`.
    /// `placement` 클로저는 실측 텍스트 사이즈를 받아 좌하단 원점(CoreAnimation) 기준 좌측 하단 좌표를 반환한다.
    /// timeRange 구간 동안만 `opacity` 값으로 표시, 그 외엔 model value(0)로 복귀.
    private static func makeOverlayTextLayer(
        text: String,
        fontSize: CGFloat,
        timeRange: CMTimeRange,
        opacity: CGFloat = 1.0,
        staticRender: Bool = false,
        placement: (CGSize) -> CGPoint
    ) -> CATextLayer {
        let textLayer = CATextLayer()
        let textSize = measureOverlayText(text, fontSize: fontSize)

        // CATextLayer.font 에 CGFont 를 직접 할당하는 패턴은 Swift에서 wrapping 이슈로
        // 무시되는 사례가 있어, NSAttributedString의 .font attribute 로 적용한다.
        #if canImport(UIKit)
        textLayer.string = NSAttributedString(
            string: text,
            attributes: [
                .font: overlayUIFont(fontSize: fontSize),
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

        // staticRender: 정적 이미지로 미리 렌더하는 경로 — opacity 를 목표값으로 고정하고 show 애니메이션 생략.
        // (클립 구간 동안만 합성되므로 per-frame opacity gating 불필요.)
        if staticRender {
            textLayer.opacity = Float(opacity)
            return textLayer
        }

        textLayer.opacity = 0

        // 해당 클립의 timeRange 동안만 보이게. `AVCoreAnimationBeginTimeAtZero` 는
        // CoreAnimation에서 "합성 0초"를 의미하는 매직값 (0은 "즉시"라 의미가 다름).
        // fillMode = .removed: 활성 구간 밖에서는 model value(opacity=0)로 복귀해 다음 클립과 겹치지 않게 함.
        let show = CABasicAnimation(keyPath: "opacity")
        show.fromValue = opacity
        show.toValue = opacity
        show.beginTime = AVCoreAnimationBeginTimeAtZero + CMTimeGetSeconds(timeRange.start)
        show.duration = max(0.01, CMTimeGetSeconds(timeRange.duration))
        show.fillMode = .removed
        show.isRemovedOnCompletion = false
        textLayer.add(show, forKey: "show")

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

    /// 박스 자막 라벨 한 개를 그릴 레이어들([배경 박스, 텍스트]).
    /// 스타일은 흰 배경 + 검정 글씨 + 검정 테두리로 고정. 모두 클립 `timeRange` 동안만 보인다.
    private static func makeCustomLabelLayers(
        label: ClipLabel,
        placedRect: CGRect,
        renderSize: CGSize,
        timeRange: CMTimeRange,
        staticRender: Bool = false
    ) -> [CALayer] {
        let fontSize = max(8, label.clampedSizeFraction * placedRect.height)
        let textSize = measureCustomText(label.text, fontSize: fontSize)
        let origin = customLabelOrigin(placedRect: placedRect, position: label.position, textSize: textSize, renderSize: renderSize)

        let textLayer = CATextLayer()
        textLayer.string = NSAttributedString(
            string: label.text,
            attributes: [
                .font: overlayCustomUIFont(fontSize: fontSize),
                .foregroundColor: UIColor.black,
                .kern: ClipLabel.BoxStyle.letterSpacing(for: fontSize),
            ]
        )
        textLayer.contentsScale = 2.0
        textLayer.isWrapped = false
        textLayer.alignmentMode = .center
        textLayer.frame = CGRect(origin: origin, size: textSize)

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

        if staticRender {
            textLayer.opacity = 1
            bgLayer.opacity = 1
        } else {
            textLayer.opacity = 0
            addShowAnimation(to: textLayer, timeRange: timeRange)
            bgLayer.opacity = 0
            addShowAnimation(to: bgLayer, timeRange: timeRange)
        }
        return [bgLayer, textLayer]
    }

    /// 레이어를 클립 `timeRange` 동안만 opacity=1 로 보이게 하는 애니메이션(그 외엔 model value 0).
    private static func addShowAnimation(to layer: CALayer, timeRange: CMTimeRange) {
        let show = CABasicAnimation(keyPath: "opacity")
        show.fromValue = 1.0
        show.toValue = 1.0
        show.beginTime = AVCoreAnimationBeginTimeAtZero + CMTimeGetSeconds(timeRange.start)
        show.duration = max(0.01, CMTimeGetSeconds(timeRange.duration))
        show.fillMode = .removed
        show.isRemovedOnCompletion = false
        layer.add(show, forKey: "show")
    }

    private static let backdropCIContext = CIContext(options: nil)

    /// 클립 썸네일을 가우시안 블러 → 캔버스 aspectFill 로 깐 배경 레이어(+어두운 스크림).
    /// timeRange 동안만 opacity=1. 썸네일이 없으면 nil(배경 생략 = 검정).
    private static func makeBlurredBackdropLayer(thumbnailData: Data?, renderSize: CGSize, timeRange: CMTimeRange) -> CALayer? {
        guard let data = thumbnailData, let ui = UIImage(data: data), let cg = ui.cgImage else { return nil }
        let ci = CIImage(cgImage: cg)
        guard let blur = CIFilter(name: "CIGaussianBlur") else { return nil }
        blur.setValue(ci, forKey: kCIInputImageKey)
        blur.setValue(min(renderSize.width, renderSize.height) * 0.04, forKey: kCIInputRadiusKey)
        guard let out = blur.outputImage,
              let rendered = backdropCIContext.createCGImage(out.cropped(to: ci.extent), from: ci.extent) else { return nil }

        let layer = CALayer()
        layer.frame = CGRect(origin: .zero, size: renderSize)
        layer.contents = rendered
        layer.contentsGravity = .resizeAspectFill
        layer.masksToBounds = true
        layer.opacity = 0
        addShowAnimation(to: layer, timeRange: timeRange)

        let scrim = CALayer()
        scrim.frame = layer.bounds
        scrim.backgroundColor = UIColor.black.withAlphaComponent(0.18).cgColor
        layer.addSublayer(scrim)
        return layer
    }
    #endif

    // MARK: - RenderSize

    /// 최종 출력 캔버스 — 9:16 세로 고정.
    public static let outputSize = CGSize(width: 1080, height: 1920)

    /// 출력 캔버스는 입력 클립과 무관하게 항상 `outputSize`(1080×1920).
    /// 비율이 다른 클립은 `transform()` 이 aspectFit + 가운데 정렬로 자동 letterbox/pillarbox 처리하고,
    /// 남는 여백은 블러 배경 레이어가 채운다. (시그니처는 호출부 호환을 위해 유지)
    public static func resolveRenderSize(
        clips: [Clip],
        rotations: [Clip.ID: ClipRotation]
    ) async -> CGSize {
        outputSize
    }

    // MARK: - Transform helper

    /// 한 클립을 renderSize 안에 aspectFit(=맞춤)으로 배치하고, 사용자 변환(scale·offset)을 추가 적용한 affine transform.
    /// framing == .fit 이면 기존 맞춤 동작과 동일(회귀 가드).
    public static func transform(
        naturalSize: CGSize,
        preferredTransform: CGAffineTransform,
        rotation: ClipRotation,
        renderSize: CGSize,
        framing: ClipTransform
    ) -> CGAffineTransform {
        let displayRect = CGRect(origin: .zero, size: naturalSize).applying(preferredTransform)
        let displaySize = CGSize(width: abs(displayRect.width), height: abs(displayRect.height))
        let postRotationSize: CGSize = rotation.swapsAxes
            ? CGSize(width: displaySize.height, height: displaySize.width)
            : displaySize

        let normalizeAfterPreferred = CGAffineTransform(translationX: -displayRect.minX, y: -displayRect.minY)

        let rotationMatrix = rotation.transform
        let rotatedRect = CGRect(origin: .zero, size: displaySize).applying(rotationMatrix)
        let rotationNormalize = CGAffineTransform(translationX: -rotatedRect.minX, y: -rotatedRect.minY)

        // fit 배율은 ClipFraming 과 공유. 사용자 배율(>=1)을 곱한다.
        let fitScale = ClipFraming.fitScale(display: displaySize, rotation: rotation, render: renderSize)
        let userScale = max(0.05, framing.scale)
        let totalScale = fitScale * userScale

        let scaledSize = CGSize(width: postRotationSize.width * totalScale,
                                height: postRotationSize.height * totalScale)
        let scaleMatrix = CGAffineTransform(scaleX: totalScale, y: totalScale)
        let centerTranslate = CGAffineTransform(translationX: (renderSize.width - scaledSize.width) / 2,
                                                y: (renderSize.height - scaledSize.height) / 2)

        // 사용자 이동(정규화 비율 → 픽셀). clamp 도 ClipFraming 공유.
        let clampedFrac = ClipFraming.clampedOffset(framing.offset, display: displaySize,
                                                    rotation: rotation, render: renderSize, scale: userScale)
        let offsetTranslate = CGAffineTransform(translationX: clampedFrac.x * renderSize.width,
                                                y: clampedFrac.y * renderSize.height)

        return preferredTransform
            .concatenating(normalizeAfterPreferred)
            .concatenating(rotationMatrix)
            .concatenating(rotationNormalize)
            .concatenating(scaleMatrix)
            .concatenating(centerTranslate)
            .concatenating(offsetTranslate)
    }

    /// `transform()` 의 aspectFILL 버전. 배경 블러 필 전용 — 항상 캔버스를 꽉 채우고(중앙) 사용자 scale/offset 은 무시한다.
    /// preferredTransform·회전 처리는 `transform()` 과 동일, fit 의 `min(...)` 배율만 `max(...)` 로 교체.
    public static func fillTransform(
        naturalSize: CGSize,
        preferredTransform: CGAffineTransform,
        rotation: ClipRotation,
        renderSize: CGSize
    ) -> CGAffineTransform {
        let displayRect = CGRect(origin: .zero, size: naturalSize).applying(preferredTransform)
        let displaySize = CGSize(width: abs(displayRect.width), height: abs(displayRect.height))
        let postRotationSize: CGSize = rotation.swapsAxes
            ? CGSize(width: displaySize.height, height: displaySize.width)
            : displaySize

        let normalizeAfterPreferred = CGAffineTransform(translationX: -displayRect.minX, y: -displayRect.minY)

        let rotationMatrix = rotation.transform
        let rotatedRect = CGRect(origin: .zero, size: displaySize).applying(rotationMatrix)
        let rotationNormalize = CGAffineTransform(translationX: -rotatedRect.minX, y: -rotatedRect.minY)

        // fill 배율: 짧은 축이 아니라 긴 축 기준으로 캔버스를 덮도록 max.
        let w = max(postRotationSize.width, 1)
        let h = max(postRotationSize.height, 1)
        let rawScale = max(renderSize.width / w, renderSize.height / h)
        let fillScale = (rawScale.isFinite && rawScale > 0) ? rawScale : 1

        let scaledSize = CGSize(width: postRotationSize.width * fillScale,
                                height: postRotationSize.height * fillScale)
        let scaleMatrix = CGAffineTransform(scaleX: fillScale, y: fillScale)
        let centerTranslate = CGAffineTransform(translationX: (renderSize.width - scaledSize.width) / 2,
                                                y: (renderSize.height - scaledSize.height) / 2)

        return preferredTransform
            .concatenating(normalizeAfterPreferred)
            .concatenating(rotationMatrix)
            .concatenating(rotationNormalize)
            .concatenating(scaleMatrix)
            .concatenating(centerTranslate)
    }

    /// 한 클립이 renderSize 안에서 aspectFit + 가운데 정렬됐을 때 차지하는 사각형(줌 미반영 = 라벨 기준).
    public static func placedRect(
        naturalSize: CGSize,
        preferredTransform: CGAffineTransform,
        rotation: ClipRotation,
        renderSize: CGSize
    ) -> CGRect {
        let displayRect = CGRect(origin: .zero, size: naturalSize).applying(preferredTransform)
        let displaySize = CGSize(width: abs(displayRect.width), height: abs(displayRect.height))
        return ClipFraming.resolvedRect(display: displaySize, rotation: rotation, render: renderSize, transform: .fit)
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
