import Foundation
import CoreGraphics
import Testing
import Models
import CompositionService

struct CompositionTransformTests {

    /// r0 + 가로 클립 → 정사각 캔버스: aspectFill(센터 크롭)로 상하 꽉 + 좌우 넘침.
    /// 1920×1080 → 1080×1080: fillScale max(1080/1920, 1080/1080) = 1.0, scaledSize 1920×1080,
    /// 좌상단 ((1080-1920)/2 = -420, 0)에 매핑.
    @Test func testTransform_R0_AspectFillCenterCrop() {
        let natural = CGSize(width: 1920, height: 1080)
        let render = CGSize(width: 1080, height: 1080)
        let t = AVFoundationCompositionService.transform(
            naturalSize: natural,
            preferredTransform: .identity,
            rotation: .r0,
            renderSize: render,
            framing: .fill
        )
        let origin = CGPoint(x: 0, y: 0).applying(t)
        let topRight = CGPoint(x: natural.width, y: 0).applying(t)
        let bottomLeft = CGPoint(x: 0, y: natural.height).applying(t)
        #expect(abs(origin.x - (-420)) < 0.5, "좌상단 x는 -420이어야 함: \(origin.x)")
        #expect(abs(origin.y - 0) < 0.5, "좌상단 y는 0이어야 함: \(origin.y)")
        #expect(abs(topRight.x - 1500) < 0.5, "우상단 x는 1500이어야 함: \(topRight.x)")
        #expect(abs(bottomLeft.y - 1080) < 0.5, "좌하단 y는 1080이어야 함: \(bottomLeft.y)")
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
            renderSize: render,
            framing: .fill
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
            renderSize: render,
            framing: .fill
        )
        let mapped = CGPoint(x: 0, y: 0).applying(t)
        #expect(abs(mapped.x - render.width) < 0.5)
        #expect(abs(mapped.y - render.height) < 0.5)
    }

    /// 같은 비율 세로 클립 720×1280 → 1080×1920 캔버스: fillScale 1.5, 풀스크린 정확히 채움.
    @Test func testTransform_AspectFill_PortraitClip_FillsRenderExactly() {
        let natural = CGSize(width: 720, height: 1280)
        let render = CGSize(width: 1080, height: 1920)
        let t = AVFoundationCompositionService.transform(
            naturalSize: natural,
            preferredTransform: .identity,
            rotation: .r0,
            renderSize: render,
            framing: .fill
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

    /// 가로 1920×1080 → 1080×1920 캔버스: fillScale 1920/1080 = 1.77778(상하 기준),
    /// scaledSize 3413.33×1920 → 상하 꽉 + 좌우 센터 크롭(좌상단 x = -1166.67).
    @Test func testTransform_AspectFill_LandscapeClip_CenterCropsSides() {
        let natural = CGSize(width: 1920, height: 1080)
        let render = CGSize(width: 1080, height: 1920)
        let t = AVFoundationCompositionService.transform(
            naturalSize: natural,
            preferredTransform: .identity,
            rotation: .r0,
            renderSize: render,
            framing: .fill
        )
        let topLeft = CGPoint(x: 0, y: 0).applying(t)
        let bottomRight = CGPoint(x: natural.width, y: natural.height).applying(t)
        // scaledSize = 3413.33 × 1920, 좌측 crop = (3413.33-1080)/2 = 1166.67
        #expect(abs(topLeft.x - (-1166.67)) < 0.5, "좌상단 x는 -1166.67: \(topLeft.x)")
        #expect(abs(topLeft.y - 0) < 0.5, "좌상단 y는 0: \(topLeft.y)")
        #expect(abs(bottomRight.x - 2246.67) < 0.5, "우하단 x는 2246.67: \(bottomRight.x)")
        #expect(abs(bottomRight.y - 1920) < 0.5, "우하단 y는 1920: \(bottomRight.y)")
    }

    /// 정사각 1080×1080 → 1080×1920 캔버스: fillScale 1920/1080 = 1.77778,
    /// scaledSize 1920×1920 → 상하 꽉 + 좌우 센터 크롭(좌상단 x = -420).
    @Test func testTransform_AspectFill_SquareClip_CenterCropsSides() {
        let natural = CGSize(width: 1080, height: 1080)
        let render = CGSize(width: 1080, height: 1920)
        let t = AVFoundationCompositionService.transform(
            naturalSize: natural,
            preferredTransform: .identity,
            rotation: .r0,
            renderSize: render,
            framing: .fill
        )
        let topLeft = CGPoint(x: 0, y: 0).applying(t)
        let bottomRight = CGPoint(x: natural.width, y: natural.height).applying(t)
        // 좌측 crop = (1920-1080)/2 = 420
        #expect(abs(topLeft.x - (-420)) < 0.5, "좌상단 x는 -420: \(topLeft.x)")
        #expect(abs(topLeft.y - 0) < 0.5, "좌상단 y는 0: \(topLeft.y)")
        #expect(abs(bottomRight.x - 1500) < 0.5, "우하단 x는 1500: \(bottomRight.x)")
        #expect(abs(bottomRight.y - 1920) < 0.5, "우하단 y는 1920: \(bottomRight.y)")
    }

    /// 가로 1920×1080 + r90 + 1080×1920 → 풀스크린 fill.
    /// r90 회전 후 postRotationSize 1080×1920 = renderSize → fillScale 1.0.
    @Test func testTransform_AspectFill_LandscapeClip_R90_ExactlyFills() {
        let natural = CGSize(width: 1920, height: 1080)
        let render = CGSize(width: 1080, height: 1920)
        let t = AVFoundationCompositionService.transform(
            naturalSize: natural,
            preferredTransform: .identity,
            rotation: .r90,
            renderSize: render,
            framing: .fill
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

    /// 1080×1920 + r0 + 1080×1920: fillScale 1.0, 첫 클립과 캔버스 동일 → identity 매핑.
    @Test func testTransform_AspectFill_FirstClipIdentity_Unchanged() {
        let natural = CGSize(width: 1080, height: 1920)
        let render = CGSize(width: 1080, height: 1920)
        let t = AVFoundationCompositionService.transform(
            naturalSize: natural,
            preferredTransform: .identity,
            rotation: .r0,
            renderSize: render,
            framing: .fill
        )
        let topLeft = CGPoint(x: 0, y: 0).applying(t)
        let bottomRight = CGPoint(x: natural.width, y: natural.height).applying(t)
        #expect(abs(topLeft.x - 0) < 0.5 && abs(topLeft.y - 0) < 0.5, "좌상단 (0,0): \(topLeft)")
        #expect(abs(bottomRight.x - 1080) < 0.5 && abs(bottomRight.y - 1920) < 0.5,
                "우하단 (1080,1920): \(bottomRight)")
    }

    /// renderSize == .zero: fillScale 가드 작동, transform이 NaN/Inf 없이 유한.
    @Test func testTransform_AspectFill_ZeroRenderSize_FallsBackToIdentityScale() {
        let natural = CGSize(width: 1080, height: 1920)
        let render = CGSize.zero
        let t = AVFoundationCompositionService.transform(
            naturalSize: natural,
            preferredTransform: .identity,
            rotation: .r0,
            renderSize: render,
            framing: .fill
        )
        let mapped = CGPoint(x: natural.width / 2, y: natural.height / 2).applying(t)
        #expect(t.a.isFinite && t.b.isFinite && t.c.isFinite && t.d.isFinite,
                "transform a/b/c/d 유한해야 함")
        #expect(t.tx.isFinite && t.ty.isFinite, "transform tx/ty 유한해야 함")
        #expect(mapped.x.isFinite && mapped.y.isFinite, "매핑 좌표 유한해야 함")
    }

    /// scale=2: 세로 클립이 2배로 커져 캔버스를 넘는다. 중심은 캔버스 중앙 유지.
    /// 1080×1920 + fill(1.0)×2 → scaledSize 2160×3840, 좌상단 (-540, -960).
    @Test func testTransform_UserScale2_GrowsFromCenter() {
        let natural = CGSize(width: 1080, height: 1920)
        let render = CGSize(width: 1080, height: 1920)
        let t = AVFoundationCompositionService.transform(
            naturalSize: natural, preferredTransform: .identity, rotation: .r0,
            renderSize: render, framing: ClipTransform(scale: 2, offset: .zero)
        )
        let topLeft = CGPoint(x: 0, y: 0).applying(t)
        let bottomRight = CGPoint(x: natural.width, y: natural.height).applying(t)
        #expect(abs(topLeft.x - (-540)) < 0.5, "x \(topLeft.x)")
        #expect(abs(topLeft.y - (-960)) < 0.5, "y \(topLeft.y)")
        #expect(abs(bottomRight.x - 1620) < 0.5, "x \(bottomRight.x)")
        #expect(abs(bottomRight.y - 2880) < 0.5, "y \(bottomRight.y)")
    }

    /// offset: scale=2 로 키운 뒤 x=+0.5 비율 이동 → 중심이 +540px 우측으로.
    @Test func testTransform_UserOffset_ShiftsCenter() {
        let natural = CGSize(width: 1080, height: 1920)
        let render = CGSize(width: 1080, height: 1920)
        let t = AVFoundationCompositionService.transform(
            naturalSize: natural, preferredTransform: .identity, rotation: .r0,
            renderSize: render, framing: ClipTransform(scale: 2, offset: CGPoint(x: 0.5, y: 0))
        )
        let center = CGPoint(x: 540, y: 960).applying(t)
        #expect(abs(center.x - 1080) < 0.5, "cx \(center.x)")
        #expect(abs(center.y - 960) < 0.5, "cy \(center.y)")
    }

    /// 가로 클립 + offset 한계값: 좌측 크롭이 전부 풀려 소스 좌측 끝이 캔버스 좌측에 닿는다.
    /// 1920×1080 → fill 1.77778, maxFracX = (3413.33-1080)/2/1080 = 1.08025.
    @Test func testTransform_LandscapeOffsetAtLimit_RevealsSourceEdge() {
        let natural = CGSize(width: 1920, height: 1080)
        let render = CGSize(width: 1080, height: 1920)
        let maxFrac = ClipFraming.maxOffsetFraction(
            display: natural, rotation: .r0, render: render, scale: 1.0
        )
        let t = AVFoundationCompositionService.transform(
            naturalSize: natural, preferredTransform: .identity, rotation: .r0,
            renderSize: render, framing: ClipTransform(scale: 1, offset: CGPoint(x: maxFrac.x, y: 0))
        )
        let topLeft = CGPoint(x: 0, y: 0).applying(t)
        #expect(abs(topLeft.x - 0) < 0.5, "한계 offset 에서 소스 좌측 끝 = 캔버스 좌측: \(topLeft.x)")
    }

    /// 축소(scale 0.5): 하한 1.0 으로 clamp → fill 그대로 렌더(여백/블러 배경이 없으므로 축소 금지).
    @Test func testTransform_UserScaleBelowMin_ClampsToFill() {
        let natural = CGSize(width: 1080, height: 1920)
        let render = CGSize(width: 1080, height: 1920)
        let t = AVFoundationCompositionService.transform(
            naturalSize: natural, preferredTransform: .identity, rotation: .r0,
            renderSize: render, framing: ClipTransform(scale: 0.5, offset: .zero)
        )
        let topLeft = CGPoint(x: 0, y: 0).applying(t)
        let bottomRight = CGPoint(x: natural.width, y: natural.height).applying(t)
        #expect(abs(topLeft.x - 0) < 0.5 && abs(topLeft.y - 0) < 0.5, "좌상단 (0,0): \(topLeft)")
        #expect(abs(bottomRight.x - 1080) < 0.5 && abs(bottomRight.y - 1920) < 0.5,
                "우하단 (1080,1920): \(bottomRight)")
    }
}
