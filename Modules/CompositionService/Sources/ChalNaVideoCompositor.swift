import AVFoundation
import CoreImage
import CoreGraphics

/// 한 클립 구간의 합성 파라미터. 전경(aspectFit+사용자변환)과 배경(aspectFill 블러)을 위한
/// y-down(natural→render) CGAffineTransform 두 개를 담는다.
final class ChalNaCompositionInstruction: NSObject, AVVideoCompositionInstructionProtocol, @unchecked Sendable {
    let timeRange: CMTimeRange          // 이 설명서가 적용되는 시간 구간.
    let enablePostProcessing: Bool = false
    let containsTweening: Bool = false  // 프레임 사이 보간 안 함(소스 부족 시 복제만).
    let requiredSourceTrackIDs: [NSValue]?
    let passthroughTrackID: CMPersistentTrackID = kCMPersistentTrackID_Invalid  // 통과(원본 그대로) 안 함 → 항상 합성.

    let trackID: CMPersistentTrackID    // 어느 트랙의 프레임을 읽을지.
    let foreground: CGAffineTransform   // natural→render, y-down (Self.transform 결과)
    let background: CGAffineTransform   // natural→render, y-down (aspectFill, 중앙)
    let blurRadius: CGFloat             // 배경 가우시안 블러 세기.
    let scrimAlpha: CGFloat             // 배경 위 검정막 진하기(0.18).
    /// 이 클립 구간에 전경 위로 올릴, 이미 renderSize 로 미리 렌더한 정적 라벨 오버레이(top-left origin).
    /// nil 이면 라벨 없음 → 합성 스킵.
    let overlayImage: CGImage?

    init(timeRange: CMTimeRange, trackID: CMPersistentTrackID, foreground: CGAffineTransform,
         background: CGAffineTransform, blurRadius: CGFloat, scrimAlpha: CGFloat,
         overlayImage: CGImage? = nil) {
        self.timeRange = timeRange
        self.trackID = trackID
        self.requiredSourceTrackIDs = [NSNumber(value: trackID)]
        self.foreground = foreground
        self.background = background
        self.blurRadius = blurRadius
        self.scrimAlpha = scrimAlpha
        self.overlayImage = overlayImage
        super.init()
    }
}

/// 9:16 캔버스의 여백(letterbox/pillarbox)을 클립의 aspectFill 블러 버전으로 채우는 커스텀 컴포지터.
/// 전경은 aspectFit + 사용자 변환, 배경은 aspectFill + 가우시안 블러 + 어두운 스크림.
final class ChalNaVideoCompositor: NSObject, AVVideoCompositing, @unchecked Sendable {
    let sourcePixelBufferAttributes: [String: any Sendable]? =
        [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
    let requiredPixelBufferAttributesForRenderContext: [String: any Sendable] =
        [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]

    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {}

    func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
        guard let instruction = request.videoCompositionInstruction as? ChalNaCompositionInstruction,
              let srcBuffer = request.sourceFrame(byTrackID: instruction.trackID),
              let dest = request.renderContext.newPixelBuffer() else {
            request.finish(with: NSError(domain: "ChalNaVideoCompositor", code: -1))
            return
        }
        let render = request.renderContext.size
        let renderRect = CGRect(origin: .zero, size: render)
        let src = CIImage(cvPixelBuffer: srcBuffer)

        // y-down(natural→render) 변환을 CIImage(y-up) 에 적용하는 헬퍼.
        //
        // 입력 t 는 "소스의 좌상단 픽셀(y-down) → render 의 좌상단 기준(y-down)" 매핑이다
        // (`AVFoundationCompositionService.transform(...)` 결과). 이는 AVFoundation 의
        // layer-instruction `setTransform(t)` 가 기대하는 좌표계와 동일하다.
        // 그러나 CoreImage 는 y-up(좌하단 원점)이라, 이 y-down 변환을 그대로 쓰면 상하가 뒤집힌다.
        //
        // 올바른 변환은 두 번의 flip 으로 좌표계를 맞춰주는 것:
        //   combined = flipV(renderH) ∘ T ∘ flipV(srcH)
        //   1) flipV(srcH): CIImage(y-up) 소스를 t 가 기대하는 y-down 소스 공간으로 변환
        //   2) T:           y-down 소스 → y-down render
        //   3) flipV(renderH): y-down render 결과를 다시 CIImage(y-up) 출력 공간으로 변환
        // (source flip 누락 시 영상이 상하/좌우로 반전된다 — `CompositorOrientationTests` 가
        //  layer-instruction 정석 경로를 oracle 로 비교 검증.)
        func placeYDown(_ image: CIImage, _ t: CGAffineTransform) -> CIImage {
            let flipSrc = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: image.extent.height)
            let flipRender = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: render.height)
            let combined = flipSrc.concatenating(t).concatenating(flipRender)
            return image.transformed(by: combined)
        }

        // ① 배경: aspectFill + 블러 + 어두운 스크림.
        let bgPlaced = placeYDown(src, instruction.background).clampedToExtent()
        let blurred = bgPlaced.applyingGaussianBlur(sigma: instruction.blurRadius).cropped(to: renderRect)
        let scrim = CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: instruction.scrimAlpha)).cropped(to: renderRect)
        let background = scrim.composited(over: blurred)

        // ② 전경: aspectFit + 사용자 변환.
        let foreground = placeYDown(src, instruction.foreground).cropped(to: renderRect)

        var output = foreground.composited(over: background).cropped(to: renderRect)

        // ③ 라벨 오버레이: 이미 renderSize 로 미리 렌더한 "정상 방향(top-left, visual-top=row0)" 정적 이미지.
        // 전경/배경은 `placeYDown` 의 두 flip 으로 "소스 visual-top → 출력 visual-top" 이 되도록 맞춰져 있다.
        // 반면 `CIImage(cgImage:)` 는 CGImage 의 visual-top 을 y-up CIImage 의 high-y 에 두므로, 그대로
        // 합성하면 전경과 상하가 반대로 놓인다(라벨이 아래로 감). renderH 기준 한 번 flip 해 전경과 정렬한다.
        // (`CompositorLabelTests` 의 TOP 라벨 위치 가드로 확정.)
        if let overlay = instruction.overlayImage {
            let flipOverlay = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: render.height)
            let overlayCI = CIImage(cgImage: overlay).transformed(by: flipOverlay)
            output = overlayCI.composited(over: output).cropped(to: renderRect)
        }

        ciContext.render(output, to: dest)
        request.finish(withComposedVideoFrame: dest)
    }
}
