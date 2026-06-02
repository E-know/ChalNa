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
    /// 1080×1920 캔버스에서 전경 클립이 뒤집힘 없이 올바른 위치에 놓이고
    /// 위/아래 여백이 블러 필(검정 아님)로 채워졌는지 확인한다.
    @Test func testCompositor_PlacesForegroundUnflipped_AndFillsLetterboxWithBlur() async throws {
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

        // 라벨 OFF (이번 작업 범위 밖).
        let labels = LabelSettings(
            timeEnabled: false, timePosition: .center, timeOpacity: 0,
            dateEnabled: false, datePosition: .bottomCenter, dateOpacity: 0
        )

        let service = AVFoundationCompositionService()
        var outURL: URL?
        for await event in service.export(clips: [clip], rotations: [:], transforms: [:], labelSettings: labels, clipLabels: [:]) {
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

        // 640×360(16:9) → 1080×1920: fitScale = 1080/640 = 1.6875,
        // 클립 rect = 1080 × 607.5, 세로 가운데 → y ∈ [656.25, 1263.75].
        // 4분면(전경, 선명): 좌상 RED · 우상 GREEN · 좌하 BLUE · 우하 YELLOW.
        let topLeft = sampler.rgb(x: 270, y: 760)
        let topRight = sampler.rgb(x: 810, y: 760)
        let bottomLeft = sampler.rgb(x: 270, y: 1160)
        let bottomRight = sampler.rgb(x: 810, y: 1160)
        let topBar = sampler.rgb(x: 540, y: 100)
        let bottomBar = sampler.rgb(x: 540, y: 1850)

        print("[CompositorRenderTests] topLeft=\(topLeft) topRight=\(topRight) bottomLeft=\(bottomLeft) bottomRight=\(bottomRight) topBar=\(topBar) bottomBar=\(bottomBar)")

        // 전경 4분면: 지배 채널 관계 검사 (±tolerance).
        #expect(topLeft.r > 150 && topLeft.g < 120 && topLeft.b < 120, "좌상단은 RED여야 함: \(topLeft)")
        #expect(topRight.g > 150 && topRight.r < 120 && topRight.b < 120, "우상단은 GREEN여야 함: \(topRight)")
        #expect(bottomLeft.b > 150 && bottomLeft.r < 120 && bottomLeft.g < 120, "좌하단은 BLUE여야 함: \(bottomLeft)")
        #expect(bottomRight.r > 150 && bottomRight.g > 150 && bottomRight.b < 120, "우하단은 YELLOW여야 함: \(bottomRight)")

        // 여백: 블러 필이 있으므로 검정 아님.
        #expect(topBar.r + topBar.g + topBar.b > 60, "상단 여백이 블러 필로 채워져야 함(검정 아님): \(topBar)")
        #expect(bottomBar.r + bottomBar.g + bottomBar.b > 60, "하단 여백이 블러 필로 채워져야 함(검정 아님): \(bottomBar)")
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
            // CGContext 는 y-up. 우리가 만든 1080×1920 캔버스의 좌상단을 row0 으로 맞추려면
            // 이미지를 그대로 draw 하면 CGImage 가 y-down 으로 들어와 상하 반전된다.
            // → 좌표를 일관되게 다루기 위해, draw 후 buffer 를 그대로 두고 rgb()에서 y 를 뒤집어 읽는다.
            ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            self.pixels = buffer
        }

        /// top-down 좌표(y=0 이 화면 위쪽)로 RGB 샘플. CGContext 버퍼는 y-up 이므로 뒤집어 읽는다.
        func rgb(x: Int, y: Int) -> (r: Int, g: Int, b: Int) {
            let cx = min(max(x, 0), width - 1)
            let cyTopDown = min(max(y, 0), height - 1)
            let cy = height - 1 - cyTopDown   // y-up 버퍼로 변환
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
