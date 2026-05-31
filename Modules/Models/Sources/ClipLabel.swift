import CoreGraphics
import Foundation

/// 편집 세션 동안 클립별로 사용자가 붙이는 텍스트 라벨. 회전(`ClipRotation`)과 같은 per-clip 메타로,
/// 불변 `Clip` 이 아니라 `EditSession` 의 딕셔너리에 담는다.
public struct ClipLabel: Equatable, Sendable {
    /// 라벨 문구. 빈/공백 문자열이면 라벨 없음으로 취급.
    public var text: String
    /// 글꼴. `.memoment`("꾸꾸") 또는 `.system`(기본).
    public var font: LabelFont
    /// 표시 스타일. `.plain`(검정 글자, 배경 없음) 또는 `.boxed`(흰 글자 + 검정 배경).
    public var style: LabelTextStyle
    /// 클립 이미지 높이 대비 글자 크기 비율. `clampedSizeFraction` 으로 0.04...0.25 클램프해 사용.
    public var sizeFraction: CGFloat
    /// 클립 이미지 사각형 기준 정규화 위치(라벨 중심). x,y ∈ 0...1, y는 위(0)→아래(1) 스크린 방향.
    public var position: CGPoint

    public init(
        text: String = "",
        font: LabelFont = .memoment,
        style: LabelTextStyle = .plain,
        sizeFraction: CGFloat = 0.10,
        position: CGPoint = CGPoint(x: 0.5, y: 0.5)
    ) {
        self.text = text
        self.font = font
        self.style = style
        self.sizeFraction = sizeFraction
        self.position = position
    }

    /// 화면/영상에 그릴 라벨이 있는지.
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

/// 라벨 글꼴 선택.
public enum LabelFont: String, Sendable, CaseIterable, Codable {
    case memoment
    case system
    public var displayName: String { self == .memoment ? "꾸꾸" : "기본" }
}

/// 라벨 표시 스타일.
public enum LabelTextStyle: String, Sendable, CaseIterable, Codable {
    case plain   // 검정 글자, 배경 없음
    case boxed   // 흰 글자 + 검정 배경
    public var displayName: String { self == .plain ? "검정 글자" : "흰 글자 + 검정 배경" }
}
