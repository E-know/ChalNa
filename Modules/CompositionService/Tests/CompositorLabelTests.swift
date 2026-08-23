import Foundation
import CoreGraphics
import AVFoundation
import Testing
import Models
@testable import CompositionService

#if canImport(UIKit)
import UIKit
#endif

/// 커스텀 컴포지터(`ChalNaVideoCompositor`)가 클립별 라벨 오버레이(정적 CGImage)를 전경 위에 올바르게,
/// 그리고 상하 뒤집힘 없이 합성하는지 차분(differential) 픽셀 테스트로 검증한다.
struct CompositorLabelTests {

    /// 회색 영상에 흰색 박스 커스텀 라벨을 올렸을 때, 라벨 ON 이 OFF 보다 클립 영역에 흰색 픽셀이
    /// 확연히 더 많아야 한다. 또한 자동 시각/날짜 라벨은 우측 하단에 나타나야 한다(뒤집힘·정렬 가드).
    @Test func testCompositor_OverlaysLabel_WhiteBoxVisible_AndAutoLabelsAtBottomRight() async throws {
        let srcURL = try await makeSolidGrayVideo(width: 640, height: 360, seconds: 0.5, fps: 24)
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

        // 화면(클립) 정중앙에 큰 박스 라벨. 자동 시각/날짜 라벨은 이제 끌 수 없지만
        // 우측 하단(x≳857, y≳1736)이라 아래 중앙 샘플 영역과 겹치지 않는다.
        let label = ClipLabel(text: "TEST", sizeFraction: 0.12, position: CGPoint(x: 0.5, y: 0.5))

        // 1) WITH 커스텀 라벨
        let samplerWith = try await exportAndSample(clip: clip, clipLabels: [clip.id: label])
        // 2) WITHOUT 커스텀 라벨 (자동 시각/날짜 라벨만 있는 상태)
        let samplerWithout = try await exportAndSample(clip: clip, clipLabels: [:])

        // 640×360(16:9) → 1080×1920 aspectFit: 클립 rect y ∈ [656.25, 1263.75], 세로 중앙 ≈ 960.
        // 클립 정중앙 ±100px 영역에서 near-white(>220) 픽셀 카운트.
        let region = CGRect(x: 440, y: 860, width: 200, height: 200)
        let whiteWith = samplerWith.countNearWhite(in: region, threshold: 220)
        let whiteWithout = samplerWithout.countNearWhite(in: region, threshold: 220)

        print("[CompositorLabelTests] whiteWith=\(whiteWith) whiteWithout=\(whiteWithout)")

        // WITH 라벨: 흰 박스가 검출돼야 함.
        #expect(whiteWith > 200, "커스텀 라벨 ON 시 클립 중앙에 흰 박스 픽셀이 충분해야 함: \(whiteWith)")
        // WITHOUT: 회색 클립이라 near-white 거의 없음(자동 라벨은 우측 하단이라 이 영역에 없다).
        #expect(whiteWithout < 50, "커스텀 라벨 없을 때 클립 중앙에 near-white 픽셀이 거의 없어야 함: \(whiteWithout)")
        // 차분: 커스텀 라벨이 명확히 흰 박스를 더한다.
        #expect(whiteWith > whiteWithout + 200, "커스텀 라벨 ON 이 OFF 보다 흰 픽셀이 확연히 많아야 함: with=\(whiteWith) without=\(whiteWithout)")

        // Sanity: 비-라벨 영역(클립 좌상단 근처)은 두 케이스 모두 회색 클립이 보여야 함.
        let grayWith = samplerWith.rgb(x: 200, y: 720)
        let grayWithout = samplerWithout.rgb(x: 200, y: 720)
        #expect(isGrayish(grayWith), "커스텀 라벨 ON 시 비라벨 영역은 회색이어야 함: \(grayWith)")
        #expect(isGrayish(grayWithout), "커스텀 라벨 OFF 시 비라벨 영역은 회색이어야 함: \(grayWithout)")

        // 3) 뒤집힘·정렬 가드: 자동 시각/날짜 라벨은 우측 하단 고정이다.
        //    padding = 1920*0.04 = 76.8 (세로) / 1080*0.04 = 43.2 (가로).
        //    time ≈ 1080*0.045 ≈ 49px(높이 ≈58), date ≈ 1080*0.030 ≈ 32px(높이 ≈38), gap ≈11
        //    → 스택 전체는 대략 y ∈ [1736, 1843], 우측 정렬이라 x ≳ 857.
        //    흰 글자를 75% 불투명도로 회색(128) 위에 올리므로 코어 픽셀 ≈ 223 > threshold 200.
        let bottomRightRegion = CGRect(x: 780, y: 1720, width: 300, height: 160)
        let topRightRegion    = CGRect(x: 780, y: 40,   width: 300, height: 160)  // 상하 뒤집힘
        let bottomLeftRegion  = CGRect(x: 0,   y: 1720, width: 300, height: 160)  // 좌우 정렬 어긋남
        let brWhite = samplerWithout.countNearWhite(in: bottomRightRegion, threshold: 200)
        let trWhite = samplerWithout.countNearWhite(in: topRightRegion, threshold: 200)
        let blWhite = samplerWithout.countNearWhite(in: bottomLeftRegion, threshold: 200)
        print("[CompositorLabelTests] auto-label br=\(brWhite) tr=\(trWhite) bl=\(blWhite)")
        #expect(brWhite > 100, "자동 라벨이 우측 하단에 흰 글자로 나타나야 함: \(brWhite)")
        #expect(brWhite > trWhite, "라벨이 (뒤집히지 않고) 아래쪽에 있어야 함: br=\(brWhite) tr=\(trWhite)")
        #expect(brWhite > blWhite, "라벨이 우측 정렬이어야 함: br=\(brWhite) bl=\(blWhite)")
    }

    // MARK: - Export + sample

    private func exportAndSample(
        clip: Clip,
        clipLabels: [Clip.ID: ClipLabel]
    ) async throws -> PixelSampler {
        let service = AVFoundationCompositionService()
        var outURL: URL?
        for await event in service.export(clips: [clip], rotations: [:], transforms: [:], clipLabels: clipLabels) {
            switch event {
            case .completed(let url): outURL = url
            case .failed(let msg):
                throw NSError(domain: "CompositorLabelTests", code: 10, userInfo: [NSLocalizedDescriptionKey: "export failed: \(msg)"])
            case .progress: break
            }
        }
        guard let exportedURL = outURL else {
            throw NSError(domain: "CompositorLabelTests", code: 11, userInfo: [NSLocalizedDescriptionKey: "export never completed"])
        }
        defer { try? FileManager.default.removeItem(at: exportedURL) }

        let asset = AVURLAsset(url: exportedURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = false
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let cgImage = try await generator.image(at: CMTime(seconds: 0.25, preferredTimescale: 600)).image
        return try PixelSampler(cgImage: cgImage, width: 1080, height: 1920)
    }

    private func isGrayish(_ c: (r: Int, g: Int, b: Int)) -> Bool {
        let maxC = max(c.r, c.g, c.b)
        let minC = min(c.r, c.g, c.b)
        // 채널 간 차이가 작고(=무채색) 중간 밝기 근방.
        return (maxC - minC) < 40 && c.r > 60 && c.r < 200
    }

    // MARK: - Solid gray source video

    /// 단색 중간 회색 클린 H.264 가로 영상을 만들어 temp URL 반환.
    private func makeSolidGrayVideo(width: Int, height: Int, seconds: Double, fps: Int) async throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("compositor-label-test-\(UUID().uuidString).mp4")
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
            throw NSError(domain: "CompositorLabelTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "startWriting failed: \(String(describing: writer.error))"])
        }
        writer.startSession(atSourceTime: .zero)

        let frameCount = max(1, Int(seconds * Double(fps)))
        for frameIndex in 0..<frameCount {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 1_000_000)
            }
            let buffer = try makeGrayBuffer(pool: adaptor.pixelBufferPool, width: width, height: height)
            let pts = CMTime(value: CMTimeValue(frameIndex), timescale: CMTimeScale(fps))
            if !adaptor.append(buffer, withPresentationTime: pts) {
                throw NSError(domain: "CompositorLabelTests", code: 2, userInfo: [NSLocalizedDescriptionKey: "append failed: \(String(describing: writer.error))"])
            }
        }

        input.markAsFinished()
        await writer.finishWriting()
        if writer.status != .completed {
            throw NSError(domain: "CompositorLabelTests", code: 3, userInfo: [NSLocalizedDescriptionKey: "finishWriting failed: \(String(describing: writer.error))"])
        }
        return url
    }

    /// 단색 회색(128,128,128) BGRA 픽셀 버퍼.
    private func makeGrayBuffer(pool: CVPixelBufferPool?, width: Int, height: Int) throws -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        if let pool {
            CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &buffer)
        }
        if buffer == nil {
            let attrs: [String: Any] = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
            CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, attrs as CFDictionary, &buffer)
        }
        guard let pb = buffer else {
            throw NSError(domain: "CompositorLabelTests", code: 4, userInfo: [NSLocalizedDescriptionKey: "pixel buffer create failed"])
        }
        CVPixelBufferLockBaseAddress(pb, [])
        defer { CVPixelBufferUnlockBaseAddress(pb, []) }
        guard let base = CVPixelBufferGetBaseAddress(pb) else {
            throw NSError(domain: "CompositorLabelTests", code: 5, userInfo: [NSLocalizedDescriptionKey: "base address nil"])
        }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pb)
        let ptr = base.assumingMemoryBound(to: UInt8.self)
        let gray: UInt8 = 128
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * 4
                ptr[offset + 0] = gray // B
                ptr[offset + 1] = gray // G
                ptr[offset + 2] = gray // R
                ptr[offset + 3] = 255  // A
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
                throw NSError(domain: "CompositorLabelTests", code: 6, userInfo: [NSLocalizedDescriptionKey: "CGContext create failed"])
            }
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

        /// top-down 사각형 영역에서 r,g,b 모두 threshold 초과인 near-white 픽셀 수.
        func countNearWhite(in rect: CGRect, threshold: Int) -> Int {
            var count = 0
            let x0 = max(0, Int(rect.minX)), x1 = min(width, Int(rect.maxX))
            let y0 = max(0, Int(rect.minY)), y1 = min(height, Int(rect.maxY))
            var y = y0
            while y < y1 {
                var x = x0
                while x < x1 {
                    let c = rgb(x: x, y: y)
                    if c.r > threshold && c.g > threshold && c.b > threshold { count += 1 }
                    x += 1
                }
                y += 1
            }
            return count
        }
    }
}

private extension AVAssetImageGenerator {
    func image(at time: CMTime) async throws -> (image: CGImage, actualTime: CMTime) {
        try await withCheckedThrowingContinuation { continuation in
            generateCGImageAsynchronously(for: time) { image, actualTime, error in
                if let image {
                    continuation.resume(returning: (image, actualTime))
                } else {
                    continuation.resume(throwing: error ?? NSError(domain: "CompositorLabelTests", code: 7))
                }
            }
        }
    }
}
