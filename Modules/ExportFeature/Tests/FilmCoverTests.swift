import Foundation
import AVFoundation
import UIKit
import Testing
import Models

/// `FilmCover` — 필름 표지는 "재료(첫 클립 원본)"가 아니라 **"결과물(합성 mp4)"의 첫 프레임**이어야 한다.
///
/// 표지가 원본 클립 썸네일(원본 비율: 16:9·4:3 등)이면 홈/상세의 9:16 포스터 박스가
/// scaledToFill 로 좌우를 크게 잘라낸다(16:9 원본이면 가로의 ~32%만 보임).
/// 결과물 프레임은 항상 1080×1920(9:16)이라 박스와 비율이 일치해 잘림이 없다.
///
/// Models 에는 전용 테스트 타겟이 없어(8개 스위트 체제) 소비자인 ExportFeatureTests 에 둔다.
struct FilmCoverTests {

    /// 추출된 커버는 영상(=합성 결과물)과 같은 비율이어야 한다. 9:16 영상 → 9:16 JPEG.
    @Test func testFirstFrameJPEG_PreservesMovieAspect() async throws {
        let movieURL = try await makeSolidVideo(width: 180, height: 320, seconds: 0.2, fps: 10)
        defer { try? FileManager.default.removeItem(at: movieURL) }

        let data = await FilmCover.firstFrameJPEG(fromMovieAt: movieURL)

        let jpeg = try #require(data, "커버 추출이 nil 을 반환")
        let image = try #require(UIImage(data: jpeg))
        let aspect = image.size.width / image.size.height
        #expect(abs(aspect - 9.0 / 16.0) < 0.01, "커버 비율 \(aspect) ≠ 9:16")
    }

    /// 존재하지 않는 파일이면 nil (크래시·placeholder 없이 폴백 판단은 호출처가 한다).
    @Test func testFirstFrameJPEG_MissingFile_ReturnsNil() async {
        let ghost = FileManager.default.temporaryDirectory
            .appendingPathComponent("filmcover-missing-\(UUID().uuidString).mp4")
        let data = await FilmCover.firstFrameJPEG(fromMovieAt: ghost)
        #expect(data == nil)
    }

    /// 원본 비율(가로 16:9)로 저장된 구 썸네일은 재생성 대상이다.
    @Test func testNeedsRegeneration_SourceAspectThumbnail_True() throws {
        let landscape = try #require(solidJPEG(width: 160, height: 90))
        #expect(FilmCover.needsRegeneration(thumbnailData: landscape))
    }

    /// 이미 결과물 비율(9:16)인 커버는 재생성하지 않는다 (백필 무한 반복 방지).
    @Test func testNeedsRegeneration_RenderAspectThumbnail_False() throws {
        let portrait = try #require(solidJPEG(width: 90, height: 160))
        #expect(!FilmCover.needsRegeneration(thumbnailData: portrait))
    }

    /// 썸네일이 아예 없으면 재생성 대상이다 (movie 존재 여부는 호출처가 가드).
    @Test func testNeedsRegeneration_NilThumbnail_True() {
        #expect(FilmCover.needsRegeneration(thumbnailData: nil))
    }

    // MARK: - Helpers

    /// 단색 프레임으로 채운 클린 H.264 영상을 temp URL 로 만든다.
    /// (CompositorRenderTests.makeQuadrantVideo 와 같은 writer 패턴의 단색 축약판)
    private func makeSolidVideo(width: Int, height: Int, seconds: Double, fps: Int) async throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("filmcover-test-\(UUID().uuidString).mp4")
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
            throw NSError(domain: "FilmCoverTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "startWriting failed: \(String(describing: writer.error))"])
        }
        writer.startSession(atSourceTime: .zero)

        let frameCount = max(1, Int(seconds * Double(fps)))
        for frameIndex in 0..<frameCount {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 1_000_000)
            }
            let buffer = try makeSolidBuffer(pool: adaptor.pixelBufferPool, width: width, height: height)
            let pts = CMTime(value: CMTimeValue(frameIndex), timescale: CMTimeScale(fps))
            if !adaptor.append(buffer, withPresentationTime: pts) {
                throw NSError(domain: "FilmCoverTests", code: 2, userInfo: [NSLocalizedDescriptionKey: "append failed: \(String(describing: writer.error))"])
            }
        }

        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else {
            throw NSError(domain: "FilmCoverTests", code: 3, userInfo: [NSLocalizedDescriptionKey: "finishWriting failed: \(String(describing: writer.error))"])
        }
        return url
    }

    private func makeSolidBuffer(pool: CVPixelBufferPool?, width: Int, height: Int) throws -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        if let pool {
            CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &buffer)
        }
        if buffer == nil {
            let attrs: [String: Any] = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
            CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, attrs as CFDictionary, &buffer)
        }
        guard let pb = buffer else {
            throw NSError(domain: "FilmCoverTests", code: 4, userInfo: [NSLocalizedDescriptionKey: "pixel buffer create failed"])
        }
        CVPixelBufferLockBaseAddress(pb, [])
        defer { CVPixelBufferUnlockBaseAddress(pb, []) }
        guard let base = CVPixelBufferGetBaseAddress(pb) else {
            throw NSError(domain: "FilmCoverTests", code: 5, userInfo: [NSLocalizedDescriptionKey: "base address nil"])
        }
        // BGRA 중간 회색으로 전체 채움.
        memset(base, 0x80, CVPixelBufferGetBytesPerRow(pb) * height)
        return pb
    }

    private func solidJPEG(width: CGFloat, height: CGFloat) -> Data? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
        let image = renderer.image { context in
            UIColor.gray.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        return image.jpegData(compressionQuality: 0.8)
    }
}
