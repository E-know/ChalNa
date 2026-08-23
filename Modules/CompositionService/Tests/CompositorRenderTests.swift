import Foundation
import CoreGraphics
import AVFoundation
import Testing
import Models
@testable import CompositionService

/// 커스텀 컴포지터(`ChalNaVideoCompositor`)가 시뮬레이터에서 실제로 동작하고,
/// 좌표(상하/좌우 뒤집힘) 수학이 맞는지 픽셀 단위로 검증한다.
struct CompositorRenderTests {

    /// 4분면(좌상 RED·우상 GREEN·좌하 BLUE·우하 YELLOW) 가로 영상을 만들어 export 한 뒤,
    /// 1080×1920 캔버스에서 전경 클립이 뒤집힘 없이 aspectFill 센터 크롭으로
    /// 캔버스 전체(상하 여백 없음)를 채우는지 확인한다.
    @Test func testCompositor_PlacesForegroundUnflipped_CenterCropFillsCanvas() async throws {
        let srcURL = try await makeQuadrantVideo(width: 640, height: 360, seconds: 0.5, fps: 24)
        defer { try? FileManager.default.removeItem(at: srcURL) }

        let clip = Clip(
            kind: .video,
            capturedAt: Date(),
            duration: 0.5,
            preset: .jejuSea,
            thumbnailData: nil,
            videoURL: srcURL,
            displaySize: CGSize(width: 640, height: 360)
        )

        let service = AVFoundationCompositionService()
        var outURL: URL?
        for await event in service.export(clips: [clip], rotations: [:], transforms: [:], clipLabels: [:]) {
            switch event {
            case .completed(let url):
                outURL = url
            case .failed(let msg):
                Issue.record("export failed: \(msg)")
                return
            case .progress:
                break
            }
        }

        guard let exportedURL = outURL else {
            Issue.record("export never completed")
            return
        }
        defer { try? FileManager.default.removeItem(at: exportedURL) }

        // 약 0.25s 프레임을 정확히 추출.
        let asset = AVURLAsset(url: exportedURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = false
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let cgImage = try await generator.image(at: CMTime(seconds: 0.25, preferredTimescale: 600)).image

        // 1080×1920 RGBA8 비트맵으로 그려 픽셀 샘플.
        let sampler = try PixelSampler(cgImage: cgImage, width: 1080, height: 1920)

        // 640×360(16:9) → 1080×1920: fillScale = max(1080/640, 1920/360) = 5.3333,
        // scaled 3413.33×1920, 좌우 센터 크롭. 소스 세로 중앙선(x=320)이 출력 x=540 에 매핑.
        // 4분면(전경, 선명): 좌상 RED · 우상 GREEN · 좌하 BLUE · 우하 YELLOW (경계 x=540, y=960).
        let topLeft = sampler.rgb(x: 270, y: 480)
        let topRight = sampler.rgb(x: 810, y: 480)
        let bottomLeft = sampler.rgb(x: 270, y: 1440)
        let bottomRight = sampler.rgb(x: 810, y: 1440)
        // 구(舊) 레터박스 영역이던 최상/최하단도 이제 선명한 전경이어야 한다(블러/검정 바 없음).
        // bottomEdge 는 우측 하단 자동 라벨 근처라, 라벨을 피하는지 손계산이 아니라
        // `LabelText.stampRect` 로 확인한다 (라벨 기하가 바뀌면 여기서 먼저 실패).
        let samplePoints: [(x: Int, y: Int)] = [
            (270, 480), (810, 480), (270, 1440), (810, 1440), (270, 40), (810, 1880),
        ]
        expectClearOfAutoLabelStamp(samplePoints, capturedAt: clip.capturedAt)

        let topEdge = sampler.rgb(x: 270, y: 40)
        let bottomEdge = sampler.rgb(x: 810, y: 1880)

        print("[CompositorRenderTests] topLeft=\(topLeft) topRight=\(topRight) bottomLeft=\(bottomLeft) bottomRight=\(bottomRight) topEdge=\(topEdge) bottomEdge=\(bottomEdge)")

        // 전경 4분면: 지배 채널 관계 검사 (±tolerance).
        #expect(topLeft.r > 150 && topLeft.g < 120 && topLeft.b < 120, "좌상단은 RED여야 함: \(topLeft)")
        #expect(topRight.g > 150 && topRight.r < 120 && topRight.b < 120, "우상단은 GREEN여야 함: \(topRight)")
        #expect(bottomLeft.b > 150 && bottomLeft.r < 120 && bottomLeft.g < 120, "좌하단은 BLUE여야 함: \(bottomLeft)")
        #expect(bottomRight.r > 150 && bottomRight.g > 150 && bottomRight.b < 120, "우하단은 YELLOW여야 함: \(bottomRight)")

        // 캔버스 최상/최하단까지 선명한 4분면 색 — 레터박스/블러 배경이 없어야 한다.
        #expect(topEdge.r > 150 && topEdge.g < 120 && topEdge.b < 120, "최상단도 RED 전경이어야 함: \(topEdge)")
        #expect(bottomEdge.r > 150 && bottomEdge.g > 150 && bottomEdge.b < 120, "최하단도 YELLOW 전경이어야 함: \(bottomEdge)")
    }

    /// 축소(scale 0.5): 전경이 캔버스를 못 덮고 상·하단에 여백이 생긴다. 그 여백은 **검정**이어야 한다
    /// (`ChalNaVideoCompositor` 의 불투명 검정 베이스). 이 사실은 지금까지 주석에만 있었다.
    ///
    /// 기하: 640×360 → fillScale = max(1080/640, 1920/360) = 5.3333, ×0.5 = 2.6667
    ///       → 전경 1706.67×960, 캔버스 중앙 배치 → y ∈ [480, 1440) 만 전경, 그 밖은 검정.
    ///       x 는 여전히 넘침(1706.67 > 1080)이라 좌우 여백은 없다.
    @Test func testCompositor_ScaleBelowFill_LeavesBlackMargin() async throws {
        let srcURL = try await makeQuadrantVideo(width: 640, height: 360, seconds: 0.5, fps: 24)
        defer { try? FileManager.default.removeItem(at: srcURL) }

        let clip = Clip(
            kind: .video,
            capturedAt: Date(),
            duration: 0.5,
            preset: .jejuSea,
            thumbnailData: nil,
            videoURL: srcURL,
            displaySize: CGSize(width: 640, height: 360)
        )

        let service = AVFoundationCompositionService()
        var outURL: URL?
        for await event in service.export(
            clips: [clip], rotations: [:],
            transforms: [clip.id: ClipTransform(scale: 0.5, offset: .zero)],
            clipLabels: [:]
        ) {
            switch event {
            case .completed(let url): outURL = url
            case .failed(let msg): Issue.record("export failed: \(msg)"); return
            case .progress: break
            }
        }
        guard let exportedURL = outURL else {
            Issue.record("export never completed")
            return
        }
        defer { try? FileManager.default.removeItem(at: exportedURL) }

        let asset = AVURLAsset(url: exportedURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = false
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let cgImage = try await generator.image(at: CMTime(seconds: 0.25, preferredTimescale: 600)).image
        let sampler = try PixelSampler(cgImage: cgImage, width: 1080, height: 1920)

        // 여백 샘플 2곳(상단 밴드·하단 밴드 좌측) + 전경 샘플 1곳.
        // 자동 시각/날짜 라벨은 우측 하단이라 여백 밴드와 겹칠 수 있다 —
        // 손계산 주석이 아니라 `LabelText.stampRect` 로 회피를 확인한다.
        let samplePoints: [(x: Int, y: Int)] = [(100, 100), (100, 1800), (270, 700)]
        expectClearOfAutoLabelStamp(samplePoints, capturedAt: clip.capturedAt)

        let topMargin = sampler.rgb(x: 100, y: 100)
        let bottomMargin = sampler.rgb(x: 100, y: 1800)
        // x=270 → 소스 좌측 절반, y=700 → 전경 상단 절반 → 4분면 좌상 RED.
        let foreground = sampler.rgb(x: 270, y: 700)

        print("[CompositorRenderTests] topMargin=\(topMargin) bottomMargin=\(bottomMargin) foreground=\(foreground)")

        #expect(topMargin.r < 24 && topMargin.g < 24 && topMargin.b < 24,
                "축소 시 상단 여백은 검정이어야 함: \(topMargin)")
        #expect(bottomMargin.r < 24 && bottomMargin.g < 24 && bottomMargin.b < 24,
                "축소 시 하단 여백은 검정이어야 함: \(bottomMargin)")
        #expect(foreground.r > 150 && foreground.g < 120 && foreground.b < 120,
                "축소된 전경 상단 좌측은 RED 여야 함: \(foreground)")
    }

    // MARK: - Helpers

    /// 4분면 색상으로 채워진 클린 H.264 가로 영상을 만들어 temp URL 반환.
    /// 좌상 RED·우상 GREEN·좌하 BLUE·우하 YELLOW (상하/좌우 뒤집힘을 픽셀로 검출 가능하게).
    private func makeQuadrantVideo(width: Int, height: Int, seconds: Double, fps: Int) async throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("compositor-test-\(UUID().uuidString).mp4")
        try? FileManager.default.removeItem(at: url)

        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        let adaptorAttrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: adaptorAttrs)
        writer.add(input)

        guard writer.startWriting() else {
            throw NSError(domain: "CompositorRenderTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "startWriting failed: \(String(describing: writer.error))"])
        }
        writer.startSession(atSourceTime: .zero)

        let frameCount = max(1, Int(seconds * Double(fps)))
        for frameIndex in 0..<frameCount {
            // input 이 준비될 때까지 대기.
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 1_000_000)
            }
            let buffer = try makeQuadrantBuffer(pool: adaptor.pixelBufferPool, width: width, height: height)
            let pts = CMTime(value: CMTimeValue(frameIndex), timescale: CMTimeScale(fps))
            if !adaptor.append(buffer, withPresentationTime: pts) {
                throw NSError(domain: "CompositorRenderTests", code: 2, userInfo: [NSLocalizedDescriptionKey: "append failed: \(String(describing: writer.error))"])
            }
        }

        input.markAsFinished()
        await writer.finishWriting()
        if writer.status != .completed {
            throw NSError(domain: "CompositorRenderTests", code: 3, userInfo: [NSLocalizedDescriptionKey: "finishWriting failed: \(String(describing: writer.error))"])
        }
        return url
    }

    /// 4분면 BGRA 픽셀 버퍼 생성. 좌표는 top-down (row 0 = 영상 위쪽).
    /// 좌상 RED·우상 GREEN·좌하 BLUE·우하 YELLOW.
    private func makeQuadrantBuffer(pool: CVPixelBufferPool?, width: Int, height: Int) throws -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        if let pool {
            CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &buffer)
        }
        if buffer == nil {
            let attrs: [String: Any] = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
            CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, attrs as CFDictionary, &buffer)
        }
        guard let pb = buffer else {
            throw NSError(domain: "CompositorRenderTests", code: 4, userInfo: [NSLocalizedDescriptionKey: "pixel buffer create failed"])
        }
        CVPixelBufferLockBaseAddress(pb, [])
        defer { CVPixelBufferUnlockBaseAddress(pb, []) }
        guard let base = CVPixelBufferGetBaseAddress(pb) else {
            throw NSError(domain: "CompositorRenderTests", code: 5, userInfo: [NSLocalizedDescriptionKey: "base address nil"])
        }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pb)
        let ptr = base.assumingMemoryBound(to: UInt8.self)
        let halfW = width / 2
        let halfH = height / 2
        // BGRA: byte0=B, byte1=G, byte2=R, byte3=A.
        for y in 0..<height {
            for x in 0..<width {
                let top = y < halfH
                let left = x < halfW
                let (r, g, b): (UInt8, UInt8, UInt8)
                if top && left {        // RED
                    (r, g, b) = (255, 0, 0)
                } else if top && !left { // GREEN
                    (r, g, b) = (0, 255, 0)
                } else if !top && left { // BLUE
                    (r, g, b) = (0, 0, 255)
                } else {                 // YELLOW
                    (r, g, b) = (255, 255, 0)
                }
                let offset = y * bytesPerRow + x * 4
                ptr[offset + 0] = b
                ptr[offset + 1] = g
                ptr[offset + 2] = r
                ptr[offset + 3] = 255
            }
        }
        return pb
    }

    /// CGImage 를 고정 크기 RGBA8 비트맵에 그려 픽셀(top-down)을 샘플.
    private struct PixelSampler {
        let pixels: [UInt8]
        let width: Int
        let height: Int

        init(cgImage: CGImage, width: Int, height: Int) throws {
            self.width = width
            self.height = height
            let bytesPerRow = width * 4
            var buffer = [UInt8](repeating: 0, count: bytesPerRow * height)
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            guard let ctx = buffer.withUnsafeMutableBytes({ raw -> CGContext? in
                CGContext(
                    data: raw.baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: bytesPerRow,
                    space: colorSpace,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                )
            }) else {
                throw NSError(domain: "CompositorRenderTests", code: 6, userInfo: [NSLocalizedDescriptionKey: "CGContext create failed"])
            }
            // `ctx.draw` 후 메모리 row 0 = 시각상 위쪽(top)이 된다. 따라서 top-down 좌표를
            // 그대로(`cy = y`) 읽으면 화면 위쪽이 올바르게 샘플된다.
            ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            self.pixels = buffer
        }

        /// top-down 좌표(y=0 이 화면 위쪽)로 RGB 샘플. `ctx.draw` 후 메모리 row 0 = 시각상 위쪽이므로 `cy = y`.
        func rgb(x: Int, y: Int) -> (r: Int, g: Int, b: Int) {
            let cx = min(max(x, 0), width - 1)
            let cy = min(max(y, 0), height - 1)
            let offset = cy * width * 4 + cx * 4
            return (Int(pixels[offset + 0]), Int(pixels[offset + 1]), Int(pixels[offset + 2]))
        }
    }
}

private extension AVAssetImageGenerator {
    /// async image(at:) 결과를 (CGImage, CMTime) 으로 받는 래퍼.
    func image(at time: CMTime) async throws -> (image: CGImage, actualTime: CMTime) {
        try await withCheckedThrowingContinuation { continuation in
            generateCGImageAsynchronously(for: time) { image, actualTime, error in
                if let image {
                    continuation.resume(returning: (image, actualTime))
                } else {
                    continuation.resume(throwing: error ?? NSError(domain: "CompositorRenderTests", code: 7))
                }
            }
        }
    }
}
