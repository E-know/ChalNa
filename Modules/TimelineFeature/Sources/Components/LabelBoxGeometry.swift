import CoreGraphics
import DesignSystem

/// 라벨 위치 정규화에 쓰는 "클립 표시 박스" 기하.
/// 실제 계산은 `ChalNaCanvasGeometry` 가 단일 출처로 갖는다 —
/// 에디터·미리보기·합성이 같은 규칙을 공유해 WYSIWYG 가 어긋나지 않게 한다.
enum LabelBoxGeometry {
    static func fittedBox(aspect: CGFloat, in available: CGSize) -> CGSize {
        ChalNaCanvasGeometry.fittedBox(aspect: aspect, in: available)
    }
}
