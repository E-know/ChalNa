import Foundation
import CoreGraphics
import QuartzCore
import SwiftUI
import Testing
import Models
@testable import CompositionService

#if canImport(UIKit)
import UIKit
#endif

/// 박스 자막 회전의 기하 계약.
///
/// 위험 지점이 셋이다. ① 오버레이 부모 레이어는 `isGeometryFlipped = true` 라 회전 부호가
/// 뒤집힐 수 있다. ② 오버레이 비트맵은 라벨이 덮는 사각형만 렌더하므로 회전 바운딩을
/// 반영하지 않으면 **모서리가 잘린다.** ③ 회전 0 에서 기존 기하와 픽셀 단위로 같아야 한다.
struct ClipLabelRotationTests {

    private let canvas = CGSize(width: 1080, height: 1920)
    private var placed: CGRect { CGRect(origin: .zero, size: CGSize(width: 1080, height: 1920)) }

    /// 프리뷰와 합성이 같은 부호 규약을 쓴다. 규약은 `ClipLabel` 한곳에만 있고,
    /// 실제 시각 방향은 아래 `rotationSignMatchesPreviewInOverlayBitmap` 이 픽셀로 잠근다.
    @Test func previewAndLayerRotationAgreeOnSign() {
        let label = ClipLabel(text: "제주", rotationRadians: 0.4)
        let preview = label.previewRotation.radians
        let layer = label.layerRotationTransform
        let layerAngle = atan2(layer.b, layer.a)
        #expect(abs(abs(preview) - abs(Double(layerAngle))) < 1e-9, "회전 각도 크기가 다르다")
        #expect(preview * Double(layerAngle) > 0,
                "프리뷰(\(preview))와 합성(\(layerAngle))의 회전 부호가 어긋난다")
    }

    #if canImport(UIKit)
    /// 회전 0: 배경·텍스트 레이어 프레임이 회전 도입 전과 동일해야 한다(회귀 가드).
    /// 기대값은 손계산이 아니라 SSOT(`ClipLabelMetrics` + `customLabelOrigin`)로 재계산해 대조한다.
    @Test func zeroRotationKeepsLegacyGeometry() {
        let label = ClipLabel(text: "제주 바다", sizeFraction: 0.10, position: CGPoint(x: 0.4, y: 0.6))
        let layers = AVFoundationCompositionService.makeCustomLabelLayers(
            label: label, placedRect: placed, renderSize: canvas
        )
        let fontPx = ClipLabelMetrics.fontPx(
            text: label.text, userSizeFraction: label.clampedSizeFraction, canvasHeight: canvas.height
        )
        let textSize = ClipLabelMetrics.textSize(label.text, fontPx: fontPx)
        let origin = AVFoundationCompositionService.customLabelOrigin(
            placedRect: placed, position: label.position, textSize: textSize, renderSize: canvas
        )
        let padX = fontPx * ClipLabel.BoxStyle.horizontalPaddingFraction
        let padY = fontPx * ClipLabel.BoxStyle.verticalPaddingFraction

        #expect(layers.count == 2)
        #expect(layers[1].frame == CGRect(origin: origin, size: textSize))
        #expect(layers[0].frame == CGRect(x: origin.x - padX, y: origin.y - padY,
                                          width: textSize.width + padX * 2,
                                          height: textSize.height + padY * 2))
        #expect(layers.allSatisfy { $0.affineTransform().isIdentity },
                "회전 0 인데 항등이 아닌 변환이 걸렸다")
    }

    /// 회전해도 배경 박스와 텍스트의 **중심이 일치**한다 — 두 레이어에 같은 아핀을 걸어도
    /// 컨테이너 레이어와 결과가 같은 이유가 바로 이 중심 일치다. 깨지면 배경이 글자와 어긋난다.
    @Test func rotatedBackgroundAndTextShareCenter() {
        for radians in [CGFloat(0), CGFloat(0.35), CGFloat(-0.9), CGFloat.pi / 2] {
            let label = ClipLabel(text: "제주 바다", sizeFraction: 0.10,
                                  position: CGPoint(x: 0.5, y: 0.5),
                                  rotationRadians: radians)
            let layers = AVFoundationCompositionService.makeCustomLabelLayers(
                label: label, placedRect: placed, renderSize: canvas
            )
            #expect(layers.count == 2)
            let bg = layers[0].position, text = layers[1].position
            #expect(abs(bg.x - text.x) < 1e-6 && abs(bg.y - text.y) < 1e-6,
                    "radians \(radians): 배경 중심 \(bg) != 텍스트 중심 \(text)")
            let bgAngle = atan2(layers[0].affineTransform().b, layers[0].affineTransform().a)
            let textAngle = atan2(layers[1].affineTransform().b, layers[1].affineTransform().a)
            #expect(abs(bgAngle - textAngle) < 1e-9, "radians \(radians): 두 레이어 회전각이 다르다")
        }
    }

    /// 회전 스탬프 박스가 회전된 바운딩을 **포함**한다(모서리 잘림 없음).
    /// 45° 는 가로로 긴 박스의 바운딩 높이가 가장 크게 커지는 근방이다.
    @Test func stampRectContainsRotatedBoundingBox() {
        let base = ClipLabel(text: "제주 바다", sizeFraction: 0.10, position: CGPoint(x: 0.5, y: 0.5))
        var tilted = base
        tilted.rotationRadians = .pi / 4

        let upright = AVFoundationCompositionService.customLabelStampRect(
            label: base, placedRect: placed, renderSize: canvas
        )
        let rect = AVFoundationCompositionService.customLabelStampRect(
            label: tilted, placedRect: placed, renderSize: canvas
        )
        #expect(rect.height > upright.height,
                "45° 회전인데 스탬프 높이가 커지지 않았다: \(rect.height) vs \(upright.height)")
        #expect(abs(rect.midX - upright.midX) < 1e-6 && abs(rect.midY - upright.midY) < 1e-6,
                "회전은 중심을 옮기지 않아야 한다: \(rect) vs \(upright)")
    }

    /// **부호의 시각 방향을 픽셀로 잠근다.**
    ///
    /// 절대 기울기를 재지 않고 **+회전과 −회전의 차분**을 본다 — 오버레이 비트맵에는 우측 하단
    /// 자동 시각/날짜 라벨이 함께 들어가 좌/우 절반의 y 중심을 한쪽으로 편향시키는데, 그 기여는
    /// 두 렌더에서 완전히 동일하므로 차분에서 사라진다. 시계방향이 + 라면 +회전 쪽에서
    /// (오른쪽 y − 왼쪽 y) 가 더 커야 한다(top-left 좌표계에서 y 가 크면 아래).
    @Test func rotationSignMatchesPreviewInOverlayBitmap() throws {
        func rightMinusLeft(_ radians: CGFloat) throws -> CGFloat {
            var label = ClipLabel(text: "AAAAAAAA", sizeFraction: 0.12,
                                  position: CGPoint(x: 0.5, y: 0.5))
            label.rotationRadians = radians
            let rendered = try #require(AVFoundationCompositionService.renderLabelOverlayImage(
                renderSize: canvas, capturedAt: fixedDate, clipLabel: label
            ), "오버레이 렌더 실패 (radians \(radians))")
            let (left, right) = try opaqueCentroidYByHalf(rendered.image)
            return right - left
        }
        let plus = try rightMinusLeft(0.5)
        let minus = try rightMinusLeft(-0.5)
        #expect(plus > minus,
                "시계방향(+) 회전이 반시계(−)보다 오른쪽을 더 아래로 기울여야 한다: +0.5 → \(plus), -0.5 → \(minus)")
    }

    /// 오버레이 캐시 키(`OverlayKey`)가 회전을 구분한다 — 같은 문구·같은 시각이라도
    /// 회전이 다르면 다른 그림이다. `ClipLabel: Hashable` 이라 자동으로 반영되어야 한다.
    @Test func rotationChangesLabelHashValue() {
        let a = ClipLabel(text: "제주", rotationRadians: 0)
        let b = ClipLabel(text: "제주", rotationRadians: 0.4)
        #expect(a.hashValue != b.hashValue)
    }

    // MARK: - Helpers

    /// 자동 라벨 문자열이 실행 시각에 따라 달라지지 않게 고정한다(비트맵 크기 재현성).
    private var fixedDate: Date { Date(timeIntervalSince1970: 1_750_000_000) }

    /// 비트맵의 좌/우 절반에서 불투명 픽셀의 평균 y(top-left 기준).
    ///
    /// 버퍼는 `CGContext` 가 직접 관리하게 한다(`data: nil`) — Swift 배열의
    /// `withUnsafeMutableBytes` 로 얻은 포인터를 클로저 밖에서 쓰는 것은 수명이 보장되지 않는다.
    private func opaqueCentroidYByHalf(_ image: CGImage) throws -> (CGFloat, CGFloat) {
        let w = image.width, h = image.height
        let ctx = try #require(
            CGContext(data: nil, width: w, height: h,
                      bitsPerComponent: 8, bytesPerRow: w * 4,
                      space: CGColorSpaceCreateDeviceRGB(),
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
            "CGContext 생성 실패"
        )
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        let base = try #require(ctx.data, "CGContext 비트맵 데이터 없음")
        let pixels = base.assumingMemoryBound(to: UInt8.self)
        let bytesPerRow = ctx.bytesPerRow
        var sums: [CGFloat] = [0, 0]
        var counts: [CGFloat] = [0, 0]
        for y in 0..<h {
            for x in 0..<w where pixels[y * bytesPerRow + x * 4 + 3] > 128 {
                let half = x < w / 2 ? 0 : 1
                sums[half] += CGFloat(y)
                counts[half] += 1
            }
        }
        #expect(counts[0] > 0 && counts[1] > 0, "라벨 픽셀이 좌우 절반 모두에 있어야 한다")
        return (sums[0] / max(counts[0], 1), sums[1] / max(counts[1], 1))
    }
    #endif
}
