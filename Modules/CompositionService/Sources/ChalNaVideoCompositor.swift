import AVFoundation
import CoreImage
import CoreGraphics

/// 한 클립 구간의 합성 파라미터. 전경(aspectFill 센터 크롭 + 사용자 변환)을 위한
/// y-down(natural→render) CGAffineTransform 을 담는다.
final class ChalNaCompositionInstruction: NSObject, AVVideoCompositionInstructionProtocol, @unchecked Sendable {
    let timeRange: CMTimeRange          // 이 설명서가 적용되는 시간 구간.
    let enablePostProcessing: Bool = false
    let containsTweening: Bool = false  // 프레임 사이 보간 안 함(소스 부족 시 복제만).
    let requiredSourceTrackIDs: [NSValue]?
    let passthroughTrackID: CMPersistentTrackID = kCMPersistentTrackID_Invalid  // 통과(원본 그대로) 안 함 → 항상 합성.

    let trackID: CMPersistentTrackID    // 어느 트랙의 프레임을 읽을지.
    let foreground: CGAffineTransform   // natural→render, y-down (Self.transform 결과)
    /// 이 클립 구간에 전경 위로 올릴 정적 라벨 오버레이(정상 방향 = top-left, visual-top=row0).
    ///
    /// **캔버스 전체가 아니라 라벨이 실제로 덮는 사각형만** 담는다 — 1080×1920 RGBA 는 장당 ≈8MB 라
    /// 클립 수만큼 곱하면 export 내내 그대로 살아 있다(instructions 가 선반영되므로 스트리밍이 아니다).
    /// 그림이 놓일 위치는 `overlayOrigin` 이 알려준다.
    let overlayImage: CGImage?
    /// `overlayImage` 좌상단이 렌더 캔버스에서 놓일 좌표(top-left 원점).
    /// 캔버스 전체 오버레이면 `.zero` 라 기존 동작과 동일하다.
    let overlayOrigin: CGPoint

    init(timeRange: CMTimeRange, trackID: CMPersistentTrackID, foreground: CGAffineTransform,
         overlayImage: CGImage? = nil, overlayOrigin: CGPoint = .zero) {
        self.timeRange = timeRange
        self.trackID = trackID
        self.requiredSourceTrackIDs = [NSNumber(value: trackID)]
        self.foreground = foreground
        self.overlayImage = overlayImage
        self.overlayOrigin = overlayOrigin
        super.init()
    }
}

/// 9:16 캔버스에 전경(aspectFill 센터 크롭 + 사용자 변환)을 배치하고 라벨 오버레이를 얹는 커스텀 컴포지터.
/// 전경이 캔버스를 항상 꽉 덮으므로 배경(블러) 레이어는 없다. 만일의 경계 틈은 검정 베이스가 받친다.
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

        // ① 전경: aspectFill(센터 크롭) + 사용자 변환. 서브픽셀 경계 틈 대비 검정 베이스 위에 얹는다.
        let base = CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: 1)).cropped(to: renderRect)
        let foreground = placeYDown(src, instruction.foreground).cropped(to: renderRect)
        var output = foreground.composited(over: base).cropped(to: renderRect)

        // ② 라벨 오버레이: 미리 렌더한 "정상 방향(top-left, visual-top=row0)" 정적 이미지.
        // 전경은 `placeYDown` 의 두 flip 으로 "소스 visual-top → 출력 visual-top" 이 되도록 맞춰져 있다.
        // 반면 `CIImage(cgImage:)` 는 CGImage 의 visual-top 을 y-up CIImage 의 high-y 에 두므로, 그대로
        // 합성하면 전경과 상하가 반대로 놓인다(라벨이 아래로 감). 자기 높이 기준으로 한 번 flip 한 뒤
        // `overlayOrigin`(top-left) 이 가리키는 자리로 옮겨 전경과 정렬한다.
        // 캔버스 전체 오버레이(origin .zero, h = render.height)면 예전의 단일 flip 과 정확히 같은 식이다.
        // (`CompositorLabelTests` 의 라벨 위치 가드로 확정.)
        if let overlay = instruction.overlayImage {
            let h = CGFloat(overlay.height)
            let origin = instruction.overlayOrigin
            let flipOverlay = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: h)
            let place = CGAffineTransform(translationX: origin.x, y: render.height - origin.y - h)
            let overlayCI = CIImage(cgImage: overlay).transformed(by: flipOverlay.concatenating(place))
            output = overlayCI.composited(over: output).cropped(to: renderRect)
        }

        ciContext.render(output, to: dest)
        request.finish(withComposedVideoFrame: dest)
    }
}
