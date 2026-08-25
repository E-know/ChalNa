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

    /// 배경 유무는 해시에도 반영된다. `ClipLabel` 은 합성 오버레이 캐시 키(`CompositionService`
    /// 의 `OverlayKey`)의 필드라, `hash(into:)` 를 손으로 쓰면서 이 필드를 빠뜨리면 ON/OFF 가
    /// 한 버킷에 몰린다. 해시 불일치 자체는 `Hashable` 계약이 보장하지 않지만(충돌은 합법),
    /// 합성 구현에서 1비트 차이가 충돌할 확률은 무시할 수준이라 실질 가드로 쓴다.
    @Test func hasBackgroundParticipatesInHashing() {
        let on = ClipLabel(text: "제주 바다", hasBackground: true)
        let off = ClipLabel(text: "제주 바다", hasBackground: false)
        #expect(on.hashValue != off.hashValue)
    }
}
