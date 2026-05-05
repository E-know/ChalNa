import Foundation
import CoreGraphics
import Testing
import Models
import CompositionService

struct CompositionTransformTests {

    /// r0 + 가로 클립 → 정사각 캔버스: aspectFit으로 좌우 꽉 + 상하 letterbox.
    /// 1920×1080 → 1080×1080: fitScale 1080/1920 = 0.5625, scaledSize 1080×607.5,
    /// 좌상단 (0, (1080-607.5)/2 = 236.25)에 매핑.
    @Test func testTransform_R0_AspectFitWithLetterbox() {
        let natural = CGSize(width: 1920, height: 1080)
        let render = CGSize(width: 1080, height: 1080)
        let t = AVFoundationCompositionService.transform(
            naturalSize: natural,
            preferredTransform: .identity,
            rotation: .r0,
            renderSize: render
        )
        let origin = CGPoint(x: 0, y: 0).applying(t)
        let topRight = CGPoint(x: natural.width, y: 0).applying(t)
        let bottomLeft = CGPoint(x: 0, y: natural.height).applying(t)
        #expect(abs(origin.x - 0) < 0.5, "좌상단 x는 0이어야 함: \(origin.x)")
        #expect(abs(origin.y - 236.25) < 0.5, "좌상단 y는 236.25이어야 함: \(origin.y)")
        #expect(abs(topRight.x - 1080) < 0.5, "우상단 x는 1080이어야 함: \(topRight.x)")
        #expect(abs(bottomLeft.y - (236.25 + 607.5)) < 0.5, "좌하단 y는 843.75이어야 함: \(bottomLeft.y)")
    }

    /// r90: 가로 1920×1080 클립이 r90 회전 후 1080×1920로 swap되고
    /// renderSize 1080×1920에 가운데 정렬되어야 한다 (정확히 꽉 참).
    @Test func testTransform_R90_FillsRotatedCanvas() {
        let natural = CGSize(width: 1920, height: 1080)
        let render = CGSize(width: 1080, height: 1920)
        let t = AVFoundationCompositionService.transform(
            naturalSize: natural,
            preferredTransform: .identity,
            rotation: .r90,
            renderSize: render
        )
        let renderRect = CGRect(origin: .zero, size: render)
        let corners = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: natural.width, y: 0),
            CGPoint(x: 0, y: natural.height),
            CGPoint(x: natural.width, y: natural.height)
        ]
        for c in corners {
            let mapped = c.applying(t)
            #expect(mapped.x >= renderRect.minX - 0.5 && mapped.x <= renderRect.maxX + 0.5,
                    "r90 매핑된 모서리가 render width 안에 있어야 함: \(mapped.x)")
            #expect(mapped.y >= renderRect.minY - 0.5 && mapped.y <= renderRect.maxY + 0.5,
                    "r90 매핑된 모서리가 render height 안에 있어야 함: \(mapped.y)")
        }
    }

    /// r180: 사이즈 swap 없이 가운데 정렬, 180° 뒤집힘.
    @Test func testTransform_R180_KeepsAxesButFlips() {
        let natural = CGSize(width: 1080, height: 1080)
        let render = CGSize(width: 1080, height: 1080)
        let t = AVFoundationCompositionService.transform(
            naturalSize: natural,
            preferredTransform: .identity,
            rotation: .r180,
            renderSize: render
        )
        let mapped = CGPoint(x: 0, y: 0).applying(t)
        #expect(abs(mapped.x - render.width) < 0.5)
        #expect(abs(mapped.y - render.height) < 0.5)
    }

    /// 작은 세로 클립 720×1280 → 1080×1920 캔버스: fitScale 1.5, 풀스크린 fit.
    @Test func testTransform_AspectFit_PortraitClip_FillsRenderExactly() {
        let natural = CGSize(width: 720, height: 1280)
        let render = CGSize(width: 1080, height: 1920)
        let t = AVFoundationCompositionService.transform(
            naturalSize: natural,
            preferredTransform: .identity,
            rotation: .r0,
            renderSize: render
        )
        let topLeft = CGPoint(x: 0, y: 0).applying(t)
        let topRight = CGPoint(x: natural.width, y: 0).applying(t)
        let bottomLeft = CGPoint(x: 0, y: natural.height).applying(t)
        let bottomRight = CGPoint(x: natural.width, y: natural.height).applying(t)
        #expect(abs(topLeft.x - 0) < 0.5 && abs(topLeft.y - 0) < 0.5,
                "좌상단은 (0,0): \(topLeft)")
        #expect(abs(topRight.x - 1080) < 0.5 && abs(topRight.y - 0) < 0.5,
                "우상단은 (1080,0): \(topRight)")
        #expect(abs(bottomLeft.x - 0) < 0.5 && abs(bottomLeft.y - 1920) < 0.5,
                "좌하단은 (0,1920): \(bottomLeft)")
        #expect(abs(bottomRight.x - 1080) < 0.5 && abs(bottomRight.y - 1920) < 0.5,
                "우하단은 (1080,1920): \(bottomRight)")
    }

    /// 가로 1920×1080 → 1080×1920 캔버스: fitScale 0.5625, 좌우 꽉 + 상하 656.25 letterbox.
    @Test func testTransform_AspectFit_LandscapeClip_PillarboxesTopBottom() {
        let natural = CGSize(width: 1920, height: 1080)
        let render = CGSize(width: 1080, height: 1920)
        let t = AVFoundationCompositionService.transform(
            naturalSize: natural,
            preferredTransform: .identity,
            rotation: .r0,
            renderSize: render
        )
        let topLeft = CGPoint(x: 0, y: 0).applying(t)
        let bottomRight = CGPoint(x: natural.width, y: natural.height).applying(t)
        // scaledSize = 1080 × 607.5, top letterbox = (1920-607.5)/2 = 656.25
        #expect(abs(topLeft.x - 0) < 0.5, "좌상단 x는 0: \(topLeft.x)")
        #expect(abs(topLeft.y - 656.25) < 0.5, "좌상단 y는 656.25: \(topLeft.y)")
        #expect(abs(bottomRight.x - 1080) < 0.5, "우하단 x는 1080: \(bottomRight.x)")
        #expect(abs(bottomRight.y - (656.25 + 607.5)) < 0.5, "우하단 y는 1263.75: \(bottomRight.y)")
    }

    /// 정사각 1080×1080 → 1080×1920 캔버스: fitScale 1.0, 좌우 꽉 + 상하 420 letterbox.
    @Test func testTransform_AspectFit_SquareClip_PillarboxesTopBottom() {
        let natural = CGSize(width: 1080, height: 1080)
        let render = CGSize(width: 1080, height: 1920)
        let t = AVFoundationCompositionService.transform(
            naturalSize: natural,
            preferredTransform: .identity,
            rotation: .r0,
            renderSize: render
        )
        let topLeft = CGPoint(x: 0, y: 0).applying(t)
        let bottomRight = CGPoint(x: natural.width, y: natural.height).applying(t)
        // top letterbox = (1920-1080)/2 = 420
        #expect(abs(topLeft.x - 0) < 0.5)
        #expect(abs(topLeft.y - 420) < 0.5, "좌상단 y는 420: \(topLeft.y)")
        #expect(abs(bottomRight.x - 1080) < 0.5)
        #expect(abs(bottomRight.y - (420 + 1080)) < 0.5, "우하단 y는 1500: \(bottomRight.y)")
    }

    /// 가로 1920×1080 + r90 + 1080×1920 → 풀스크린 fit.
    /// r90 회전 후 postRotationSize 1080×1920 = renderSize → fitScale 1.0.
    @Test func testTransform_AspectFit_LandscapeClip_R90_ExactlyFills() {
        let natural = CGSize(width: 1920, height: 1080)
        let render = CGSize(width: 1080, height: 1920)
        let t = AVFoundationCompositionService.transform(
            naturalSize: natural,
            preferredTransform: .identity,
            rotation: .r90,
            renderSize: render
        )
        let renderRect = CGRect(origin: .zero, size: render)
        let corners = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: natural.width, y: 0),
            CGPoint(x: 0, y: natural.height),
            CGPoint(x: natural.width, y: natural.height)
        ]
        // 모서리 4점이 모두 renderRect 경계(코너)에 매핑되는지 확인.
        var mappedXs: [CGFloat] = []
        var mappedYs: [CGFloat] = []
        for c in corners {
            let m = c.applying(t)
            mappedXs.append(m.x)
            mappedYs.append(m.y)
        }
        #expect(abs((mappedXs.min() ?? 0) - renderRect.minX) < 0.5, "minX: \(mappedXs.min() ?? 0)")
        #expect(abs((mappedXs.max() ?? 0) - renderRect.maxX) < 0.5, "maxX: \(mappedXs.max() ?? 0)")
        #expect(abs((mappedYs.min() ?? 0) - renderRect.minY) < 0.5, "minY: \(mappedYs.min() ?? 0)")
        #expect(abs((mappedYs.max() ?? 0) - renderRect.maxY) < 0.5, "maxY: \(mappedYs.max() ?? 0)")
    }

    /// 1080×1920 + r0 + 1080×1920: fitScale 1.0, 첫 클립과 캔버스 동일 → identity 매핑.
    @Test func testTransform_AspectFit_FirstClipIdentity_Unchanged() {
        let natural = CGSize(width: 1080, height: 1920)
        let render = CGSize(width: 1080, height: 1920)
        let t = AVFoundationCompositionService.transform(
            naturalSize: natural,
            preferredTransform: .identity,
            rotation: .r0,
            renderSize: render
        )
        let topLeft = CGPoint(x: 0, y: 0).applying(t)
        let bottomRight = CGPoint(x: natural.width, y: natural.height).applying(t)
        #expect(abs(topLeft.x - 0) < 0.5 && abs(topLeft.y - 0) < 0.5, "좌상단 (0,0): \(topLeft)")
        #expect(abs(bottomRight.x - 1080) < 0.5 && abs(bottomRight.y - 1920) < 0.5,
                "우하단 (1080,1920): \(bottomRight)")
    }

    /// renderSize == .zero: fitScale 가드 작동, transform이 NaN/Inf 없이 유한.
    @Test func testTransform_AspectFit_ZeroRenderSize_FallsBackToIdentityScale() {
        let natural = CGSize(width: 1080, height: 1920)
        let render = CGSize.zero
        let t = AVFoundationCompositionService.transform(
            naturalSize: natural,
            preferredTransform: .identity,
            rotation: .r0,
            renderSize: render
        )
        let mapped = CGPoint(x: natural.width / 2, y: natural.height / 2).applying(t)
        #expect(t.a.isFinite && t.b.isFinite && t.c.isFinite && t.d.isFinite,
                "transform a/b/c/d 유한해야 함")
        #expect(t.tx.isFinite && t.ty.isFinite, "transform tx/ty 유한해야 함")
        #expect(mapped.x.isFinite && mapped.y.isFinite, "매핑 좌표 유한해야 함")
    }
}
