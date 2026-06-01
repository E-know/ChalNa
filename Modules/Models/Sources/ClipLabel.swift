import CoreGraphics
import Foundation

/// 편집 세션 동안 클립별로 사용자가 붙이는 박스 자막. 회전(`ClipRotation`)과 같은 per-clip 메타로,
/// 불변 `Clip` 이 아니라 `EditSession` 의 딕셔너리에 담는다.
/// 스타일은 "흰 배경 + 검정 글씨 + 검정 테두리" 박스 자막으로 고정 — 사용자는 텍스트·크기·위치만 정한다.
public struct ClipLabel: Equatable, Sendable {
    /// 자막 문구. 빈/공백 문자열이면 자막 없음으로 취급.
    public var text: String
    /// 클립 이미지 높이 대비 글자 크기 비율. `clampedSizeFraction` 으로 0.04...0.25 클램프해 사용.
    public var sizeFraction: CGFloat
    /// 클립 이미지 사각형 기준 정규화 위치(자막 중심). x,y ∈ 0...1, y는 위(0)→아래(1) 스크린 방향.
    public var position: CGPoint

    public init(
        text: String = "",
        sizeFraction: CGFloat = 0.10,
        position: CGPoint = CGPoint(x: 0.5, y: 0.5)
    ) {
        self.text = text
        self.sizeFraction = sizeFraction
        self.position = position
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
