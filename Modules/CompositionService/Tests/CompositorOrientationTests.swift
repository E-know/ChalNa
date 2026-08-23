import Foundation
import CoreGraphics
import AVFoundation
import Testing
import Models
@testable import CompositionService

/// GROUND-TRUTH orientation 검증.
///
/// 커스텀 컴포지터(`ChalNaVideoCompositor`)의 출력이, 동일한 `transform()` 을 쓰는
/// AVFoundation 의 정석(layer-instruction `setTransform`) 출력과 **방향이 일치**하는지
/// 픽셀 단위로 비교한다. layer-instruction 경로는 커스텀 컴포지터가 생기기 전의
/// orientation-correct 동작이므로, 여기서는 그것을 정답(oracle)으로 삼는다.
///
/// 두 가지 소스 방향에 대해 검증한다:
/// - (A) identity preferredTransform (가로 녹화)
/// - (B) 90° preferredTransform (세로 녹화 — 트랙 preferredTransform 이 90°)
struct CompositorOrientationTests {

    private static let renderSize = CGSize(width: 1080, height: 1920)

    // MARK: - (A) identity preferredTransform (landscape)

    @Test func testCompositor_MatchesLayerInstruction_IdentityLandscape() async throws {
        let srcURL = try await makeQuadrantVideo(width: 640, height: 360, seconds: 0.5, fps: 24, recordedRotation: nil)
        defer { try? FileManager.default.removeItem(at: srcURL) }

        // 가로(640×360, 16:9) → 1080×1920 aspectFit: 클립 rect y ∈ [656.25, 1263.75].
        // 4분면 센터를 클립 영역 안에서 샘플.
        let samplePoints: [(x: Int, y: Int)] = [
            (270, 760),   // TL
            (810, 760),   // TR
            (270, 1160),  // BL
            (810, 1160),  // BR
        ]
        try await compareCompositorToGroundTruth(srcURL: srcURL, samplePoints: samplePoints, label: "identity")
    }

    // MARK: - (B) 90° preferredTransform (portrait-recorded)

    @Test func testCompositor_MatchesLayerInstruction_Rotated90() async throws {
        // 가로 프레임(640×360) 4분면을 그리되, 트랙 preferredTransform = 90° 로 만들어
        // "세로로 녹화된" 자산을 흉내낸다. 디스플레이 사이즈는 360×640(세로).
        let srcURL = try await makeQuadrantVideo(width: 640, height: 360, seconds: 0.5, fps: 24,
                                                 recordedRotation: CGAffineTransform(rotationAngle: .pi / 2))
        defer { try? FileManager.default.removeItem(at: srcURL) }

        // 세로 표시(360×640, 9:16) → 1080×1920: 거의 꽉 참. 캔버스 4분면을 샘플.
        let samplePoints: [(x: Int, y: Int)] = [
            (270, 480),
            (810, 480),
            (270, 1440),
            (810, 1440),
        ]
        try await compareCompositorToGroundTruth(srcURL: srcURL, samplePoints: samplePoints, label: "rotated90")
    }

    // MARK: - Comparison core

    private func compareCompositorToGroundTruth(srcURL: URL, samplePoints: [(x: Int, y: Int)], label: String) async throws {
        let clip = Clip(
            kind: .video,
            capturedAt: Date(),
            duration: 0.5,
            preset: .jejuSea,
            thumbnailData: nil,
            videoURL: srcURL,
            displaySize: CGSize(width: 640, height: 360)
        )

        // 자동 시각/날짜 라벨은 이제 끌 수 없다(우측 하단 고정). ground truth 에는 라벨이 없으므로
        // 샘플 지점이 라벨 박스(대략 x∈[857,1037], y∈[1736,1843])를 피해야 비교가 성립한다 —
        // 위 두 테스트의 지점(x=270·810, y≤1440)은 모두 그 밖이다.
        // --- GROUND TRUTH (canonical layer-instruction) ---
        let truthURL = try await exportGroundTruth(srcURL: srcURL)
        defer { try? FileManager.default.removeItem(at: truthURL) }
        let truthSampler = try await sample(url: truthURL)

        // --- COMPOSITOR ---
        let service = AVFoundationCompositionService()
        var compURL: URL?
        for await event in service.export(clips: [clip], rotations: [:], transforms: [:], clipLabels: [:]) {
            switch event {
            case .completed(let u): compURL = u
            case .failed(let m): Issue.record("compositor export failed: \(m)"); return
            case .progress: break
            }
        }
        guard let compositorURL = compURL else { Issue.record("compositor export never completed"); return }
        defer { try? FileManager.default.removeItem(at: compositorURL) }
        let compSampler = try await sample(url: compositorURL)

        // --- COMPARE at identical coords ---
        for p in samplePoints {
            let truth = truthSampler.rgb(x: p.x, y: p.y)
            let comp = compSampler.rgb(x: p.x, y: p.y)
            print("[CompositorOrientationTests:\(label)] (\(p.x),\(p.y)) truth=\(truth) compositor=\(comp)")
            let dr = abs(truth.r - comp.r), dg = abs(truth.g - comp.g), db = abs(truth.b - comp.b)
            #expect(dr <= 60 && dg <= 60 && db <= 60,
                    "compositor 출력이 ground-truth 와 방향/색이 일치해야 함 @(\(p.x),\(p.y)): truth=\(truth) comp=\(comp)")
        }
    }

    /// 정석(canonical) export: 커스텀 컴포지터/animationTool 없이 layer-instruction `setTransform` 만 사용.
    private func exportGroundTruth(srcURL: URL) async throws -> URL {
        let asset = AVURLAsset(url: srcURL)
        let track = try #require(try await asset.loadTracks(withMediaType: .video).first)
        let naturalSize = try await track.load(.naturalSize)
        let preferredTransform = try await track.load(.preferredTransform)
        let duration = try await asset.load(.duration)

        let composition = AVMutableComposition()
        let compTrack = try #require(composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid))
        try compTrack.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: track, at: .zero)

        let t = AVFoundationCompositionService.transform(
            naturalSize: naturalSize,
            preferredTransform: preferredTransform,
            rotation: .r0,
            renderSize: Self.renderSize,
            framing: .fill
        )

        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compTrack)
        layerInstruction.setTransform(t, at: .zero)

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: duration)
        instruction.layerInstructions = [layerInstruction]

        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = Self.renderSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        videoComposition.instructions = [instruction]

        let session = try #require(AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality))
        session.videoComposition = videoComposition
        let outURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("orientation-truth-\(UUID().uuidString).mp4")
        try? FileManager.default.removeItem(at: outURL)
        try await session.export(to: outURL, as: .mp4)
        return outURL
    }

    /// 0.25s 프레임을 추출해 1080×1920 RGBA8 비트맵으로 샘플.
    private func sample(url: URL) async throws -> PixelSampler {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = false
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let cgImage = try await generator.image(at: CMTime(seconds: 0.25, preferredTimescale: 600)).image
        return try PixelSampler(cgImage: cgImage,
                                width: Int(Self.renderSize.width),
                                height: Int(Self.renderSize.height))
    }

    // MARK: - Quadrant source video

    /// 4분면(좌상 RED·우상 GREEN·좌하 BLUE·우하 YELLOW) 클린 H.264 영상.
    /// `recordedRotation` 을 주면 AVAssetWriterInput.transform 으로 트랙 preferredTransform 을 설정한다.
    private func makeQuadrantVideo(width: Int, height: Int, seconds: Double, fps: Int,
                                   recordedRotation: CGAffineTransform?) async throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("orientation-src-\(UUID().uuidString).mp4")
        try? FileManager.default.removeItem(at: url)

        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        if let recordedRotation {
            input.transform = recordedRotation
        }
        let adaptorAttrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: adaptorAttrs)
        writer.add(input)

        guard writer.startWriting() else {
            throw NSError(domain: "CompositorOrientationTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "startWriting failed: \(String(describing: writer.error))"])
        }
        writer.startSession(atSourceTime: .zero)

        let frameCount = max(1, Int(seconds * Double(fps)))
        for frameIndex in 0..<frameCount {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 1_000_000)
            }
            let buffer = try makeQuadrantBuffer(pool: adaptor.pixelBufferPool, width: width, height: height)
            let pts = CMTime(value: CMTimeValue(frameIndex), timescale: CMTimeScale(fps))
            if !adaptor.append(buffer, withPresentationTime: pts) {
                throw NSError(domain: "CompositorOrientationTests", code: 2, userInfo: [NSLocalizedDescriptionKey: "append failed: \(String(describing: writer.error))"])
            }
        }

        input.markAsFinished()
        await writer.finishWriting()
        if writer.status != .completed {
            throw NSError(domain: "CompositorOrientationTests", code: 3, userInfo: [NSLocalizedDescriptionKey: "finishWriting failed: \(String(describing: writer.error))"])
        }
        return url
    }

    /// 4분면 BGRA 픽셀 버퍼. row 0 = 영상 위쪽(top-down). 좌상 RED·우상 GREEN·좌하 BLUE·우하 YELLOW.
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
            throw NSError(domain: "CompositorOrientationTests", code: 4, userInfo: [NSLocalizedDescriptionKey: "pixel buffer create failed"])
        }
        CVPixelBufferLockBaseAddress(pb, [])
        defer { CVPixelBufferUnlockBaseAddress(pb, []) }
        guard let base = CVPixelBufferGetBaseAddress(pb) else {
            throw NSError(domain: "CompositorOrientationTests", code: 5, userInfo: [NSLocalizedDescriptionKey: "base address nil"])
        }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pb)
        let ptr = base.assumingMemoryBound(to: UInt8.self)
        let halfW = width / 2
        let halfH = height / 2
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

    // MARK: - Sampler (memory row 0 = visual top)

    /// CGImage 를 고정 크기 RGBA8 비트맵에 그려 픽셀을 샘플.
    /// `ctx.draw` 후 메모리 row 0 = 시각상 위쪽이므로, top-down 좌표를 그대로 읽는다(`cy = y`).
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
                throw NSError(domain: "CompositorOrientationTests", code: 6, userInfo: [NSLocalizedDescriptionKey: "CGContext create failed"])
            }
            ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            self.pixels = buffer
        }

        /// top-down 좌표(y=0 이 화면 위쪽). `ctx.draw` 후 메모리 row 0 = 시각상 위쪽이므로 `cy = y`.
        func rgb(x: Int, y: Int) -> (r: Int, g: Int, b: Int) {
            let cx = min(max(x, 0), width - 1)
            let cy = min(max(y, 0), height - 1)
            let offset = cy * width * 4 + cx * 4
            return (Int(pixels[offset + 0]), Int(pixels[offset + 1]), Int(pixels[offset + 2]))
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
                    continuation.resume(throwing: error ?? NSError(domain: "CompositorOrientationTests", code: 7))
                }
            }
        }
    }
}
