import Foundation
import Testing
import CoreGraphics
import Models

struct ClipLabelTests {

    @Test func defaultIsInvisibleAndCentered() {
        let l = ClipLabel.default
        #expect(l.isVisible == false)
        #expect(l.position == CGPoint(x: 0.5, y: 0.5))
        #expect(l.sizeFraction == 0.10)
    }

    @Test func isVisibleIgnoresWhitespace() {
        #expect(ClipLabel(text: "   ").isVisible == false)
        #expect(ClipLabel(text: "\n ").isVisible == false)
        #expect(ClipLabel(text: "제주 바다").isVisible == true)
    }

    @Test func sizeFractionClamps() {
        #expect(ClipLabel(sizeFraction: 0.001).clampedSizeFraction == ClipLabel.minSizeFraction)
        #expect(ClipLabel(sizeFraction: 9).clampedSizeFraction == ClipLabel.maxSizeFraction)
        #expect(ClipLabel(sizeFraction: 0.1).clampedSizeFraction == 0.1)
        #expect(ClipLabel(sizeFraction: ClipLabel.minSizeFraction).clampedSizeFraction == ClipLabel.minSizeFraction)
        #expect(ClipLabel(sizeFraction: ClipLabel.maxSizeFraction).clampedSizeFraction == ClipLabel.maxSizeFraction)
    }

    /// 기본은 배경 ON — 기존 라벨의 외형(흰 박스)이 그대로 유지되어야 한다.
    @Test func defaultHasBackgroundIsOn() {
        #expect(ClipLabel().hasBackground)
    }

    /// 배경 유무는 값 동등성에 참여한다 — 참여하지 않으면 토글이 뷰 갱신을 못 일으킨다.
    @Test func hasBackgroundParticipatesInEquality() {
        let on = ClipLabel(text: "제주 바다", hasBackground: true)
        let off = ClipLabel(text: "제주 바다", hasBackground: false)
        #expect(on != off)
    }

    // MARK: - 회전

    /// 회전 기본값은 0 — 기존 라벨의 외형이 그대로 유지되어야 한다.
    @Test func defaultRotationIsZero() {
        #expect(ClipLabel().rotationRadians == 0)
        #expect(ClipLabel.default.rotationRadians == 0)
    }

    /// 회전은 값 동등성에 참여한다 — 참여하지 않으면 제스처가 뷰 갱신도,
    /// 오버레이 캐시(`OverlayKey`) 무효화도 못 만든다.
    @Test func rotationParticipatesInEquality() {
        #expect(ClipLabel(text: "제주 바다", rotationRadians: 0)
                != ClipLabel(text: "제주 바다", rotationRadians: 0.3))
    }

    /// −180°…180° 자유 회전. 그 밖은 clamp.
    @Test func rotationClampsToHalfTurn() {
        #expect(ClipLabel(rotationRadians: 10).clampedRotationRadians == .pi)
        #expect(ClipLabel(rotationRadians: -10).clampedRotationRadians == -.pi)
        #expect(ClipLabel(rotationRadians: 0.5).clampedRotationRadians == 0.5)
    }
}
