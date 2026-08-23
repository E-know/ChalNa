import CoreGraphics
import Foundation

/// 편집 세션 동안 클립별로 사용자가 붙이는 박스 자막. 회전(`ClipRotation`)과 같은 per-clip 메타로,
/// 불변 `Clip` 이 아니라 `EditSession` 의 딕셔너리에 담는다.
///
/// 스타일은 `hasBackground` 로 갈린다:
/// - `true`  — 흰 배경 + 검정 글씨 + 검정 테두리 박스
/// - `false` — 배경·테두리 없는 흰 글씨(장식 없음)
///
/// 사용자가 정하는 것은 문구 · 크기 · 위치 · 배경 유무 네 가지다.
public struct ClipLabel: Hashable, Sendable {
    /// 자막 문구. 빈/공백 문자열이면 자막 없음으로 취급.
    public var text: String
    /// 9:16 캔버스 높이 대비 글자 크기 비율. `clampedSizeFraction` 으로 0.04...0.25 클램프해 사용.
    public var sizeFraction: CGFloat
    /// 9:16 캔버스 기준 정규화 위치(자막 중심). x,y ∈ 0...1, y는 위(0)→아래(1) 스크린 방향.
    public var position: CGPoint
    /// 배경 박스(흰 면 + 검정 테두리) 표시 여부. false 면 흰 글자만 그린다.
    ///
    /// **패딩은 ON/OFF 에서 동일하다.** 합성(`customLabelOrigin`)은 텍스트 크기만으로 중심을
    /// 정해 패딩과 무관하지만, 에디터(`LabelEditorView`)는 좌상단 코너를 고정하고 패딩 포함
    /// 크기로 중심을 역산한다(`LabelAnchorMath.center`) — 패딩이 바뀌면 코너는 그대로여도
    /// 중심이 옮겨가므로, 토글마다 라벨이 움직이지 않도록 패딩을 동일하게 유지한다.
    public var hasBackground: Bool

    public init(
        text: String = "",
        sizeFraction: CGFloat = 0.10,
        position: CGPoint = CGPoint(x: 0.5, y: 0.5),
        hasBackground: Bool = true
    ) {
        self.text = text
        self.sizeFraction = sizeFraction
        self.position = position
        self.hasBackground = hasBackground
    }

    /// 화면/영상에 그릴 자막이 있는지.
    public var isVisible: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 슬라이더 허용 범위.
    public static let minSizeFraction: CGFloat = 0.04
    public static let maxSizeFraction: CGFloat = 0.25

    /// 클램프된 크기 비율.
    public var clampedSizeFraction: CGFloat {
        min(max(sizeFraction, Self.minSizeFraction), Self.maxSizeFraction)
    }

    public static let `default` = ClipLabel()
}

public extension ClipLabel {
    /// 박스 자막 스타일 상수. 프리뷰(SwiftUI)와 영상 합성(CALayer)이 같은 값을 참조해 WYSIWYG 를 맞춘다.
    /// 모든 값은 폰트 픽셀(fontSize) 기준 비율.
    enum BoxStyle {
        /// 테두리 두께 = fontSize × 이 값.
        public static let borderWidthFraction: CGFloat = 0.06
        /// 가로 안쪽 여백 = fontSize × 이 값.
        public static let horizontalPaddingFraction: CGFloat = 0.35
        /// 세로 안쪽 여백 = fontSize × 이 값.
        public static let verticalPaddingFraction: CGFloat = 0.22
        /// 자간(letter spacing) = fontSize × 이 값. 음수면 자간이 좁아진다. (더 좁히려면 -0.06, -0.08 …)
        public static let letterSpacingFraction: CGFloat = -0.06

        /// fontSize 에 대한 실제 자간(point). 프리뷰(.tracking)·합성(NSAttributedString.kern)이 공유.
        public static func letterSpacing(for fontSize: CGFloat) -> CGFloat {
            fontSize * letterSpacingFraction
        }
    }
}
