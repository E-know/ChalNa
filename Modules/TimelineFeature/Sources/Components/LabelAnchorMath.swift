import CoreGraphics
import Models

/// 라벨 박스의 "좌상단(top-leading) 코너 ↔ 중심(center)" 변환 + 박스 표시 크기 측정.
///
/// 편집/크기 조정 중에는 **좌상단 코너 `(minX, minY)` 를 고정**하고 우·하로만 확장한다.
/// 다만 저장 모델(`ClipLabel.position`)은 지금처럼 **박스 중심** 기준을 유지하므로,
/// 합성(`CompositionService.customLabelOrigin`)·미리보기(`PreviewPanel`)와 WYSIWYG 가 어긋나지 않는다.
/// 코너↔중심 변환은 측정한 박스 크기를 그대로 역산하므로 왕복(round-trip) 무손실이다.
enum LabelAnchorMath {
    /// 빈 문구는 placeholder 로 실측한다 — 편집 중 인라인 TextField 폭을 글자에 맞추기 위함
    /// (기본 최소폭 제거). placeholder 치환이 이 타입의 유일한 실측 책임이다.
    static func displayText(_ text: String) -> String {
        text.isEmpty ? String(localized: "자막 입력") : text
    }

    /// 텍스트(패딩 제외)만의 표시 크기(point). 빈 문자열이면 placeholder("자막 입력") 기준.
    /// 실측 자체는 `Models.ClipLabelMetrics` 가 단일 출처다 — 합성·프리뷰와 같은 함수를 부른다.
    static func textSize(text: String, fontPx: CGFloat) -> CGSize {
        ClipLabelMetrics.textSize(displayText(text), fontPx: fontPx)
    }

    /// 텍스트 박스(흰 배경 + 검정 테두리 + 패딩 포함)의 표시 크기(point).
    /// 화면과 출력 영상의 박스 크기가 맞도록 `ClipLabelMetrics` 를 그대로 경유한다.
    static func paddedBoxSize(text: String, fontPx: CGFloat) -> CGSize {
        ClipLabelMetrics.paddedBoxSize(displayText(text), fontPx: fontPx)
    }

    /// 정규화 중심(center, x·y ∈ 0…1) → box-local 좌상단 코너(point).
    static func topLeft(center: CGPoint, in box: CGSize, paddedSize: CGSize) -> CGPoint {
        CGPoint(x: center.x * box.width - paddedSize.width / 2,
                y: center.y * box.height - paddedSize.height / 2)
    }

    /// box-local 좌상단 코너(point) → 정규화 중심(center). x·y 는 0…1 로 clamp.
    static func center(topLeft corner: CGPoint, in box: CGSize, paddedSize: CGSize) -> CGPoint {
        guard box.width > 0, box.height > 0 else { return CGPoint(x: 0.5, y: 0.5) }
        let cx = (corner.x + paddedSize.width / 2) / box.width
        let cy = (corner.y + paddedSize.height / 2) / box.height
        return CGPoint(x: min(max(cx, 0), 1), y: min(max(cy, 0), 1))
    }
}
