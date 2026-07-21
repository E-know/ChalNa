import CoreGraphics
import Models

/// 라벨 위치 정규화에 쓰는 "클립 표시 박스" 기하. 에디터·미리보기·합성이 동일 규칙을 공유해
/// WYSIWYG 가 어긋나지 않도록 한 곳에 모은다.
enum LabelBoxGeometry {
    /// 주어진 비율을 가용 영역 안에 aspect-fit 시킨 박스 크기.
    static func fittedBox(aspect: CGFloat, in available: CGSize) -> CGSize {
        guard available.width > 0, available.height > 0 else { return .zero }
        let byWidth = CGSize(width: available.width, height: available.width / aspect)
        if byWidth.height <= available.height { return byWidth }
        return CGSize(width: available.height * aspect, height: available.height)
    }
}
