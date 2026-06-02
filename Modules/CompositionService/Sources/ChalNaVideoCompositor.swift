import AVFoundation
import CoreImage
import CoreGraphics

/// 한 클립 구간의 합성 파라미터. 전경(aspectFit+사용자변환)과 배경(aspectFill 블러)을 위한
/// y-down(natural→render) CGAffineTransform 두 개를 담는다.
final class ChalNaCompositionInstruction: NSObject, AVVideoCompositionInstructionProtocol, @unchecked Sendable {
    let timeRange: CMTimeRange
    let enablePostProcessing: Bool = false
    let containsTweening: Bool = false
    let requiredSourceTrackIDs: [NSValue]?
    let passthroughTrackID: CMPersistentTrackID = kCMPersistentTrackID_Invalid

    let trackID: CMPersistentTrackID
    let foreground: CGAffineTransform   // natural→render, y-down (Self.transform 결과)
    let background: CGAffineTransform   // natural→render, y-down (aspectFill, 중앙)
    let blurRadius: CGFloat
    let scrimAlpha: CGFloat

    init(timeRange: CMTimeRange, trackID: CMPersistentTrackID, foreground: CGAffineTransform,
         background: CGAffineTransform, blurRadius: CGFloat, scrimAlpha: CGFloat) {
        self.timeRange = timeRange
        self.trackID = trackID
        self.requiredSourceTrackIDs = [NSNumber(value: trackID)]
        self.foreground = foreground
        self.background = background
        self.blurRadius = blurRadius
        self.scrimAlpha = scrimAlpha
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

        // y-down(natural→render) 변환을 CIImage 에 적용하는 헬퍼.
        //
        // 입력 t 는 "소스의 좌상단 픽셀(y-down) → render 의 좌상단 기준(y-down)" 매핑이다.
        // `CIImage(cvPixelBuffer:)` 는 버퍼의 시각상 위쪽 행이 extent 위쪽(높은 y)에 오도록
        // 들어오므로 t 를 그대로 적용하면 소스/전경의 좌상단이 그대로 보존된다.
        // 마지막에 render 결과(y-down)를 CIImage 출력(y-up) 공간으로 한 번만 상하 뒤집으면 된다.
        // (픽셀 테스트 `CompositorRenderTests` 로 4분면 비뒤집힘을 경험적으로 확정.)
        func placeYDown(_ image: CIImage, _ t: CGAffineTransform) -> CIImage {
            // render 높이 기준 상하 뒤집기 (y-down → y-up).
            let flipRender = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: render.height)
            let combined = t.concatenating(flipRender)
            return image.transformed(by: combined)
        }

        // 배경: aspectFill + 블러 + 어두운 스크림.
        let bgPlaced = placeYDown(src, instruction.background).clampedToExtent()
        let blurred = bgPlaced.applyingGaussianBlur(sigma: instruction.blurRadius).cropped(to: renderRect)
        let scrim = CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: instruction.scrimAlpha)).cropped(to: renderRect)
        let background = scrim.composited(over: blurred)

        // 전경: aspectFit + 사용자 변환.
        let foreground = placeYDown(src, instruction.foreground).cropped(to: renderRect)

        let output = foreground.composited(over: background).cropped(to: renderRect)
        ciContext.render(output, to: dest)
        request.finish(withComposedVideoFrame: dest)
    }
}
