import Foundation
import Models
import AVFoundation
import CoreGraphics
import QuartzCore
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
    /// 클립 배열·회전·자동 라벨 설정·클립별 사용자 라벨을 받아 mp4를 만들고 진행률/완료/실패를 스트림으로 흘려보낸다.
    func export(
        clips: [Clip],
        rotations: [Clip.ID: ClipRotation],
        labelSettings: LabelSettings,
        clipLabels: [Clip.ID: ClipLabel]
    ) -> AsyncStream<ExportEvent>
}

public extension CompositionServicing {
    /// 사용자 라벨 없는 호출 → 빈 라벨(현행 동작).
    func export(clips: [Clip], rotations: [Clip.ID: ClipRotation], labelSettings: LabelSettings) -> AsyncStream<ExportEvent> {
        export(clips: clips, rotations: rotations, labelSettings: labelSettings, clipLabels: [:])
    }
    /// 라벨 설정 없는 호출 → 기본값.
    func export(clips: [Clip], rotations: [Clip.ID: ClipRotation]) -> AsyncStream<ExportEvent> {
        export(clips: clips, rotations: rotations, labelSettings: .default, clipLabels: [:])
    }
    /// 회전·라벨 설정 없는 호출.
    func export(clips: [Clip]) -> AsyncStream<ExportEvent> {
        export(clips: clips, rotations: [:], labelSettings: .default, clipLabels: [:])
    }
}

/// AVFoundation 기반 실 구현체. PhotosPicker에서 받아온 videoURL들을 이어 붙여 mp4로 내보낸다.
public actor AVFoundationCompositionService: CompositionServicing {
    public init() {}

    public nonisolated func export(
        clips: [Clip],
        rotations: [Clip.ID: ClipRotation],
        labelSettings: LabelSettings,
        clipLabels: [Clip.ID: ClipLabel]
    ) -> AsyncStream<ExportEvent> {
        AsyncStream { continuation in
            let task = Task { [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }
                await self.run(clips: clips, rotations: rotations, labelSettings: labelSettings, clipLabels: clipLabels, continuation: continuation)
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Pipeline

    private func run(
        clips: [Clip],
        rotations: [Clip.ID: ClipRotation],
        labelSettings: LabelSettings,
        clipLabels: [Clip.ID: ClipLabel],
        continuation: AsyncStream<ExportEvent>.Continuation
    ) async {
        do {
            let built = try await buildComposition(clips: clips, rotations: rotations, labelSettings: labelSettings, clipLabels: clipLabels)
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
            continuation.yield(.failed(err.errorDescription ?? String(localized: "알 수 없는 오류")))
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

        // 1) 출력 캔버스는 "가장 큰 oriented height"를 가진 클립의 W×H 비율 그대로.
        //    비율이 다른 클립은 `transform()`이 aspectFit + 가운데 정렬해 letterbox/pillarbox 처리.
        let renderSize = await Self.resolveRenderSize(clips: clips, rotations: rotations)

        // 2) 시간순으로 트랙을 채우면서 클립별 layerInstruction 누적.
        var cursor = CMTime.zero
        var layerInstructions: [(timeRange: CMTimeRange, transform: CGAffineTransform, capturedAt: Date, clipID: Clip.ID, placedRect: CGRect)] = []

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
            let pRect = Self.placedRect(
                naturalSize: naturalSize,
                preferredTransform: preferredTransform,
                rotation: userRotation,
                renderSize: renderSize
            )
            layerInstructions.append((placedRange, transform, clip.capturedAt, clip.id, pRect))

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

        // 4) 각 클립 placedRange 동안 라벨 오버레이 (자동 시간/날짜 + 사용자 커스텀 라벨).
        let hasVisibleCustomLabel = clipLabels.values.contains { $0.isVisible }
        if hasContent && (labelSettings.timeEnabled || labelSettings.dateEnabled || hasVisibleCustomLabel) {
            videoComposition.animationTool = Self.makeDateLabelAnimationTool(
                renderSize: renderSize,
                entries: layerInstructions.map { ($0.timeRange, $0.capturedAt, $0.clipID, $0.placedRect) },
                labelSettings: labelSettings,
                clipLabels: clipLabels
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

    /// 클립별 촬영일시를 설정에 따라 오버레이로 합성하는 `AVVideoCompositionCoreAnimationTool`.
    /// - 시각 `HH:mm`: 큰 글씨(minDim×0.18), opacity 0.5
    /// - 날짜 `yyyy/MM/dd`: 작은 글씨(minDim×0.035), opacity 1.0
    /// 표시 여부·위치는 `labelSettings`를 따른다. 각 라벨은 자신의 timeRange 동안만 보인다.
    /// 시각·날짜가 모두 켜져 있고 위치가 같으면 세로 스택(시각 위 / 날짜 아래)으로 묶어 배치한다.
    private static func makeDateLabelAnimationTool(
        renderSize: CGSize,
        entries: [(timeRange: CMTimeRange, capturedAt: Date, clipID: Clip.ID, placedRect: CGRect)],
        labelSettings: LabelSettings,
        clipLabels: [Clip.ID: ClipLabel]
    ) -> AVVideoCompositionCoreAnimationTool {
        let parentLayer = CALayer()
        let videoLayer = CALayer()
        parentLayer.frame = CGRect(origin: .zero, size: renderSize)
        videoLayer.frame = parentLayer.frame
        parentLayer.addSublayer(videoLayer)

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
        func addCustomLabel(for entry: (timeRange: CMTimeRange, capturedAt: Date, clipID: Clip.ID, placedRect: CGRect)) {
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
        timeRange: CMTimeRange
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
        textLayer.opacity = 0
        addShowAnimation(to: textLayer, timeRange: timeRange)

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
        bgLayer.opacity = 0
        addShowAnimation(to: bgLayer, timeRange: timeRange)
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
    #endif

    // MARK: - RenderSize

    /// 출력 캔버스 결정 — "비율을 최대한 길게(가장 큰 높이를 가진 클립 기준)":
    /// 1) 모든 클립의 oriented size를 모은다 (사용자 회전 r90/r270이 axes를 swap한 뒤).
    /// 2) 그 중 **height가 가장 큰 클립의 W × H를 그대로 캔버스로 사용**.
    ///    동률은 처음 등장한 클립이 우선 (덮어쓰기 안 함).
    /// 3) mp4 인코더가 짝수 픽셀을 선호하므로 2의 배수로 스냅(올림).
    /// 4) 모든 클립의 사이즈 추출 실패 시 fallback 9:16 세로(1080×1920).
    ///
    /// 비율이 다른 클립은 `transform()`이 aspectFit + 가운데 정렬해 자동 letterbox/pillarbox 처리한다.
    public static func resolveRenderSize(
        clips: [Clip],
        rotations: [Clip.ID: ClipRotation]
    ) async -> CGSize {
        let fallback = CGSize(width: 1080, height: 1920)
        var best: CGSize? = nil
        var bestHeight: CGFloat = 0

        for clip in clips {
            guard let raw = await effectiveSize(for: clip) else { continue }
            let rot = rotations[clip.id] ?? .r0
            let oriented = rot.swapsAxes
                ? CGSize(width: raw.height, height: raw.width)
                : raw
            if oriented.height > bestHeight {     // 동률은 갱신 안 함 → 첫 등장 우선
                bestHeight = oriented.height
                best = oriented
            }
        }

        guard let pick = best else { return fallback }
        return CGSize(width: snapEven(pick.width), height: snapEven(pick.height))
    }

    /// 정수 픽셀 중에서 2의 배수로 절상 스냅. H.264 인코더의 짝수 dim 선호를 만족시키기 위해.
    private static func snapEven(_ v: CGFloat) -> CGFloat {
        let r = round(v)
        return r.truncatingRemainder(dividingBy: 2) == 0 ? r : r + 1
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

    /// 한 클립이 renderSize 안에서 aspectFit + 가운데 정렬됐을 때 차지하는 사각형.
    /// `transform()` 과 동일한 fit-scale·center 계산을 공유한다. 가운데 정렬이라 y-up/y-down 무관.
    public static func placedRect(
        naturalSize: CGSize,
        preferredTransform: CGAffineTransform,
        rotation: ClipRotation,
        renderSize: CGSize
    ) -> CGRect {
        let displayRect = CGRect(origin: .zero, size: naturalSize).applying(preferredTransform)
        let displaySize = CGSize(width: abs(displayRect.width), height: abs(displayRect.height))
        let postRotationSize: CGSize = rotation.swapsAxes
            ? CGSize(width: displaySize.height, height: displaySize.width)
            : displaySize
        let safeW = max(postRotationSize.width, minDisplayDimension)
        let safeH = max(postRotationSize.height, minDisplayDimension)
        let fitScaleRaw = min(renderSize.width / safeW, renderSize.height / safeH)
        let fitScale: CGFloat = (fitScaleRaw.isFinite && fitScaleRaw > 0) ? fitScaleRaw : 1.0
        let scaledSize = CGSize(
            width: postRotationSize.width * fitScale,
            height: postRotationSize.height * fitScale
        )
        let origin = CGPoint(
            x: (renderSize.width - scaledSize.width) / 2,
            y: (renderSize.height - scaledSize.height) / 2
        )
        return CGRect(origin: origin, size: scaledSize)
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
