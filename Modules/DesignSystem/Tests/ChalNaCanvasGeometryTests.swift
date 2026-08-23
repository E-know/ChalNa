import Testing
import CoreGraphics
import DesignSystem

/// 9:16 캔버스 aspect-fit 기하를 잠근다.
/// 프리뷰·크롭 조정·라벨 에디터가 같은 박스를 renderSize 로 삼으므로,
/// 이 값이 바뀌면 세 화면의 WYSIWYG 가 동시에 어긋난다.
struct ChalNaCanvasGeometryTests {

    private let aspect: CGFloat = 9.0 / 16.0

    @Test func testWideAvailableIsConstrainedByHeight() {
        let box = ChalNaCanvasGeometry.fittedBox(aspect: aspect,
                                                in: CGSize(width: 1000, height: 320))
        #expect(box.height == 320)
        #expect(abs(box.width - 320 * 9 / 16) < 0.001)
    }

    @Test func testTallAvailableIsConstrainedByWidth() {
        let box = ChalNaCanvasGeometry.fittedBox(aspect: aspect,
                                                in: CGSize(width: 180, height: 4000))
        #expect(box.width == 180)
        #expect(abs(box.height - 180 * 16 / 9) < 0.001)
    }

    @Test func testExactRatioReturnsAvailableUnchanged() {
        let box = ChalNaCanvasGeometry.fittedBox(aspect: aspect,
                                                in: CGSize(width: 180, height: 320))
        #expect(abs(box.width - 180) < 0.001)
        #expect(abs(box.height - 320) < 0.001)
    }

    /// aspect-fit 의 정의: 어느 축도 가용 영역을 넘지 않는다. 실기 크기로 확인.
    @Test func testResultNeverExceedsAvailable() {
        for available in [CGSize(width: 393, height: 852),
                          CGSize(width: 375, height: 667),
                          CGSize(width: 440, height: 956),
                          CGSize(width: 100, height: 100)] {
            let box = ChalNaCanvasGeometry.fittedBox(aspect: aspect, in: available)
            #expect(box.width <= available.width + 0.001)
            #expect(box.height <= available.height + 0.001)
        }
    }

    @Test func testDegenerateInputsReturnZero() {
        #expect(ChalNaCanvasGeometry.fittedBox(aspect: aspect, in: .zero) == .zero)
        #expect(ChalNaCanvasGeometry.fittedBox(aspect: aspect,
                                              in: CGSize(width: 100, height: 0)) == .zero)
        #expect(ChalNaCanvasGeometry.fittedBox(aspect: 0,
                                              in: CGSize(width: 100, height: 100)) == .zero)
    }

    /// `fittedBox` 결과를 다시 `fittedBox` 에 먹이면 그대로 나와야 한다(슬랙 0).
    /// `LabelEditorView`(:101) 는 바깥에서 계산한 box 로 `ChalNaCanvas` 의 `.frame`을 딱 맞게
    /// 제한한 뒤 그 위에서 직접 상단 정렬한다 — `ChalNaCanvas` 내부 `GeometryReader` 가 같은
    /// box 를 proxy.size 로 받아 `fittedBox` 를 다시 호출했을 때 letterbox 가 조금이라도 생기면,
    /// 캔버스 내부 정렬(.center)과 바깥 정렬(.top)이 어긋나 라벨 좌표가 다시 오정렬된다
    /// (Task 25 회귀와 같은 급의 문제). 이 항등성이 그 전제를 지킨다.
    @Test func testFittedBoxIsIdempotent_NoInternalSlack() {
        for available in [CGSize(width: 393, height: 852),
                          CGSize(width: 375, height: 667),
                          CGSize(width: 440, height: 956),
                          CGSize(width: 1000, height: 320),
                          CGSize(width: 180, height: 4000)] {
            let box = ChalNaCanvasGeometry.fittedBox(aspect: aspect, in: available)
            let reapplied = ChalNaCanvasGeometry.fittedBox(aspect: aspect, in: box)
            #expect(abs(reapplied.width - box.width) < 0.001, "width \(reapplied.width) vs \(box.width)")
            #expect(abs(reapplied.height - box.height) < 0.001, "height \(reapplied.height) vs \(box.height)")
        }
    }

    /// 위임 전 `LabelBoxGeometry` 산식을 재현해 값이 바뀌지 않았음을 직접 대조한다.
    /// TimelineFeature 는 별 모듈이라 여기서 그 타입을 호출할 수 없으므로 산식을 복제한다.
    @Test func testMatchesPreDelegationFormula() {
        func original(aspect: CGFloat, in available: CGSize) -> CGSize {
            guard available.width > 0, available.height > 0 else { return .zero }
            let byWidth = CGSize(width: available.width, height: available.width / aspect)
            if byWidth.height <= available.height { return byWidth }
            return CGSize(width: available.height * aspect, height: available.height)
        }
        for available in [CGSize(width: 393, height: 500),
                          CGSize(width: 393, height: 852),
                          CGSize(width: 200, height: 100)] {
            let new = ChalNaCanvasGeometry.fittedBox(aspect: aspect, in: available)
            let old = original(aspect: aspect, in: available)
            #expect(abs(new.width - old.width) < 0.001)
            #expect(abs(new.height - old.height) < 0.001)
        }
    }
}
