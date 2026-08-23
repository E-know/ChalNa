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
        // 우측 하단이라 아래 중앙 샘플 영역과 겹치지 않는다 (겹침 여부는 아래에서 계산으로 확인).
        let label = ClipLabel(text: "TEST", sizeFraction: 0.12, position: CGPoint(x: 0.5, y: 0.5))

        // 1) WITH 커스텀 라벨
        let samplerWith = try await exportAndSample(clip: clip, clipLabels: [clip.id: label])
        // 2) WITHOUT 커스텀 라벨 (자동 시각/날짜 라벨만 있는 상태)
        let samplerWithout = try await exportAndSample(clip: clip, clipLabels: [:])

        // 640×360(16:9) → 1080×1920 aspectFit: 클립 rect y ∈ [656.25, 1263.75], 세로 중앙 ≈ 960.
        // 클립 정중앙 ±100px 영역에서 near-white(>220) 픽셀 카운트.
        let region = CGRect(x: 440, y: 860, width: 200, height: 200)
        // 중앙 샘플 영역과 비라벨 sanity 지점이 자동 라벨 스탬프 밖인지 확인.
        expectClearOfAutoLabelStamp(
            [(Int(region.minX), Int(region.minY)), (Int(region.maxX), Int(region.maxY)), (200, 720)],
            capturedAt: clip.capturedAt
        )
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
        //    검사 영역을 손계산 주석이 아니라 실제 기하(`LabelText.stampRect`)에서 뽑는다 —
        //    LabelLayout 의 padding/폰트 분수를 조정하면 이 가드가 같이 움직인다.
        let canvas = CGSize(width: 1080, height: 1920)
        let stamp = LabelText.stampRect(renderSize: canvas, capturedAt: clip.capturedAt)

        //    임계값도 토큰에서 유도한다: 흰 글자를 `LabelLayout.opacity` 로 회색(128) 위에 올리면
        //    코어 픽셀 ≈ 128 + 127×opacity (0.75 → ≈223). 불투명도를 바꾸면 가드가 따라간다 —
        //    이게 "두 렌더 경로가 같은 불투명도를 쓰는가"를 픽셀로 붙잡는 유일한 지점이다.
        let expectedCore = 128.0 + 127.0 * LabelLayout.opacity
        let threshold = Int(expectedCore) - 24
        #expect(threshold > 128, "라벨 불투명도가 회색 배경과 구분 불가할 만큼 낮다: \(LabelLayout.opacity)")

        let bottomRightRegion = stamp
        // 상하 뒤집힘: 같은 x, y 만 캔버스 기준으로 반사.
        let topRightRegion = CGRect(x: stamp.minX, y: canvas.height - stamp.maxY,
                                    width: stamp.width, height: stamp.height)
        // 좌우 정렬 어긋남: 같은 y, x 만 반사.
        let bottomLeftRegion = CGRect(x: canvas.width - stamp.maxX, y: stamp.minY,
                                      width: stamp.width, height: stamp.height)
        let brWhite = samplerWithout.countNearWhite(in: bottomRightRegion, threshold: threshold)
        let trWhite = samplerWithout.countNearWhite(in: topRightRegion, threshold: threshold)
        let blWhite = samplerWithout.countNearWhite(in: bottomLeftRegion, threshold: threshold)
        print("[CompositorLabelTests] auto-label br=\(brWhite) tr=\(trWhite) bl=\(blWhite)")
        #expect(brWhite > 100, "자동 라벨이 우측 하단에 흰 글자로 나타나야 함: \(brWhite)")
        #expect(brWhite > trWhite, "라벨이 (뒤집히지 않고) 아래쪽에 있어야 함: br=\(brWhite) tr=\(trWhite)")
        #expect(brWhite > blWhite, "라벨이 우측 정렬이어야 함: br=\(brWhite) bl=\(blWhite)")
    }

    /// 배경 OFF 라벨: 흰 **박스**가 아니라 흰 **글자**만 올라간다.
    /// 회색 영상 중앙 200×200 영역의 near-white 픽셀 수가
    /// 배경 ON 보다 확연히 적어야 한다(박스 면적이 사라졌으므로).
    @Test func testCompositor_BackgroundOffLabel_NoWhiteBox() async throws {
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

        let on = ClipLabel(text: "TEST", sizeFraction: 0.12,
                           position: CGPoint(x: 0.5, y: 0.5), hasBackground: true)
        let off = ClipLabel(text: "TEST", sizeFraction: 0.12,
                            position: CGPoint(x: 0.5, y: 0.5), hasBackground: false)

        let samplerOn = try await exportAndSample(clip: clip, clipLabels: [clip.id: on])
        let samplerOff = try await exportAndSample(clip: clip, clipLabels: [clip.id: off])

        let region = CGRect(x: 440, y: 860, width: 200, height: 200)
        expectClearOfAutoLabelStamp(
            [(Int(region.minX), Int(region.minY)), (Int(region.maxX), Int(region.maxY))],
            capturedAt: clip.capturedAt
        )
        let whiteOn = samplerOn.countNearWhite(in: region, threshold: 220)
        let whiteOff = samplerOff.countNearWhite(in: region, threshold: 220)

        print("[CompositorLabelTests] whiteOn=\(whiteOn) whiteOff=\(whiteOff)")

        // 흰 글자만 남으므로 near-white 픽셀은 있지만(글리프), 박스 면적만큼은 없다.
        #expect(whiteOff > 0, "배경 OFF 도 흰 글자는 보여야 함: \(whiteOff)")
        #expect(whiteOff < whiteOn / 2,
                "배경 OFF 는 박스 면적만큼 흰 픽셀이 줄어야 함: on=\(whiteOn) off=\(whiteOff)")
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
