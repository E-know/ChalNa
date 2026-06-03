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

    /// 앱에서 선택한 표시 언어(없으면 시스템)에 맞춘 오버레이 로케일.
    /// 스위즐은 `Bundle` 만 바꾸므로 `Locale.current` 는 기기 언어를 반영한다.
    /// 따라서 앱 선택 언어("appLanguage")를 직접 읽어 매핑한다.
    private static func overlayLocale() -> Locale {
        switch UserDefaults.standard.string(forKey: "appLanguage") {
        case "ko": return Locale(identifier: "ko")
        case "en": return Locale(identifier: "en")
        case "ja": return Locale(identifier: "ja")
        default:   return Locale.current
        }
    }

    /// 우측 하단 작은 라벨용 — 날짜. 글리프-세이프 숫자 형식(로케일별 순서만 다름).
    /// en: `MM/dd/yyyy`, 그 외(ko·ja): `yyyy/MM/dd`. 현재 타임존.
    private static func dateOnlyFormatter(_ locale: Locale) -> DateFormatter {
        let f = DateFormatter()
        f.locale = locale
        f.timeZone = .current
        f.dateFormat = (locale.language.languageCode?.identifier == "en") ? "MM/dd/yyyy" : "yyyy/MM/dd"
        return f
    }

    /// 화면 정중앙 큰 라벨용 — 시:분. en: 12시간(`h:mm a`), 그 외: 24시간(`HH:mm`).
    private static func timeOnlyFormatter(_ locale: Locale) -> DateFormatter {
        let f = DateFormatter()
        f.locale = locale
        f.timeZone = .current
        f.dateFormat = (locale.language.languageCode?.identifier == "en") ? "h:mm a" : "HH:mm"
        return f
    }

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

    #if canImport(UIKit)
    /// 한 클립 구간의 라벨(시간/날짜/커스텀)을 `renderSize` 의 투명 CALayer 트리로 쌓아 정적 CGImage 로 렌더한다.
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

        let locale = overlayLocale()
        let dateText = dateOnlyFormatter(locale).string(from: capturedAt)
        let timeText = timeOnlyFormatter(locale).string(from: capturedAt)

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
                text: dateText, fontSize: dateFontSize,
                opacity: labelSettings.dateOpacity
            ) { _ in origins.date })
            parentLayer.addSublayer(makeOverlayTextLayer(
                text: timeText, fontSize: timeFontSize,
                opacity: labelSettings.timeOpacity
            ) { _ in origins.time })
        } else {
            if labelSettings.dateEnabled {
                parentLayer.addSublayer(makeOverlayTextLayer(
                    text: dateText, fontSize: dateFontSize,
                    opacity: labelSettings.dateOpacity
                ) { size in
                    labelSettings.datePosition.origin(renderSize: renderSize, textSize: size, padding: padding)
                })
            }
            if labelSettings.timeEnabled {
                parentLayer.addSublayer(makeOverlayTextLayer(
                    text: timeText, fontSize: timeFontSize,
                    opacity: labelSettings.timeOpacity
                ) { size in
                    labelSettings.timePosition.origin(renderSize: renderSize, textSize: size, padding: padding)
                })
            }
        }

        if custom.isVisible {
            for layer in makeCustomLabelLayers(
                label: custom, placedRect: placedRect, renderSize: renderSize
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
    /// opacity 를 목표값으로 고정한다(클립 구간 동안만 컴포지터가 합성하므로 per-frame gating 불필요).
    private static func makeOverlayTextLayer(
        text: String,
        fontSize: CGFloat,
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
        textLayer.opacity = Float(opacity)

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
    /// 스타일은 흰 배경 + 검정 글씨 + 검정 테두리로 고정.
    private static func makeCustomLabelLayers(
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
                .foregroundColor: UIColor.black,
                .kern: ClipLabel.BoxStyle.letterSpacing(for: fontSize),
            ]
        )
        textLayer.contentsScale = 2.0
        textLayer.isWrapped = false
        textLayer.alignmentMode = .center
        textLayer.frame = CGRect(origin: origin, size: textSize)
        textLayer.opacity = 1

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
