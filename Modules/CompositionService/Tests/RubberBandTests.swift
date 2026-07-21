import Foundation
import CoreGraphics
import Testing
import Models

/// UIScrollView 러버밴드 공식 `b = (1 − 1/((x·c/d) + 1))·d` (c=0.55) 의 성질 검증.
struct RubberBandTests {

    /// 한계 안 값은 그대로 통과.
    @Test func testValue_WithinLimits_PassesThrough() {
        let v = RubberBand.value(proposed: 0.3, min: -1.0, max: 1.0)
        #expect(abs(v - 0.3) < 0.0001, "\(v)")
    }

    /// 초과분 0 → 감쇠 0.
    @Test func testDisplacement_ZeroExcess_IsZero() {
        #expect(RubberBand.displacement(excess: 0) == 0)
        #expect(RubberBand.displacement(excess: -5) == 0)
    }

    /// 표준 수치 검증(gist.github.com/originell/6961057): d=960, c=0.55 기준
    /// 초과 5→2.74, 100→52.02, 960→340.65.
    @Test func testDisplacement_MatchesKnownUIScrollViewValues() {
        let d: CGFloat = 960
        #expect(abs(RubberBand.displacement(excess: 5, dimension: d) - 2.74) < 0.01)
        #expect(abs(RubberBand.displacement(excess: 100, dimension: d) - 52.02) < 0.01)
        #expect(abs(RubberBand.displacement(excess: 960, dimension: d) - 340.65) < 0.01)
    }

    /// 단조 증가 + 점근 캡: 감쇠 결과는 항상 dimension 미만.
    @Test func testDisplacement_MonotonicAndCapped() {
        let d: CGFloat = 1.0
        var prev: CGFloat = -1
        for x in stride(from: CGFloat(0), through: 50, by: 0.5) {
            let b = RubberBand.displacement(excess: x, dimension: d)
            #expect(b >= prev, "단조 증가 위반: x=\(x)")
            #expect(b < d, "캡 위반: x=\(x) b=\(b)")
            prev = b
        }
    }

    /// 상한 초과: 결과는 상한보다 크지만 원시 초과분보다는 작다(저항).
    @Test func testValue_AboveMax_ResistsButExceeds() {
        let v = RubberBand.value(proposed: 1.5, min: -1.0, max: 1.0)
        #expect(v > 1.0, "\(v)")
        #expect(v < 1.5, "\(v)")
    }

    /// 하한 초과: 대칭 동작.
    @Test func testValue_BelowMin_SymmetricResistance() {
        let above = RubberBand.value(proposed: 1.5, min: -1.0, max: 1.0)
        let below = RubberBand.value(proposed: -1.5, min: -1.0, max: 1.0)
        #expect(abs(above - 1.0 - (-1.0 - below)) < 0.0001, "above \(above) below \(below)")
    }

    /// 한계 폭이 0(min == max == 0)이어도 동작 — 딱 맞는 클립을 끌 때의 저항.
    @Test func testValue_ZeroRange_StillRubberBands() {
        let v = RubberBand.value(proposed: 0.2, min: 0, max: 0)
        #expect(v > 0, "\(v)")
        #expect(v < 0.2, "\(v)")
    }
}
