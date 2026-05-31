import CoreGraphics
import Foundation

/// 편집 세션 동안 클립별로 사용자가 붙이는 텍스트 라벨. 회전(`ClipRotation`)과 같은 per-clip 메타로,
/// 불변 `Clip` 이 아니라 `EditSession` 의 딕셔너리에 담는다.
public struct ClipLabel: Equatable, Sendable {
    /// 라벨 문구. 빈/공백 문자열이면 라벨 없음으로 취급.
    public var text: String
    /// 글꼴. `.memoment`("꾸꾸") 또는 `.system`(기본).
    public var font: LabelFont
    /// 배경. 흰색/검정색/투명.
    public var background: LabelBackground
    /// 글자색. 흰색/검정색.
    public var textColor: LabelColor
    /// 클립 이미지 높이 대비 글자 크기 비율. `clampedSizeFraction` 으로 0.04...0.25 클램프해 사용.
    public var sizeFraction: CGFloat
    /// 클립 이미지 사각형 기준 정규화 위치(라벨 중심). x,y ∈ 0...1, y는 위(0)→아래(1) 스크린 방향.
    public var position: CGPoint

    public init(
        text: String = "",
        font: LabelFont = .memoment,
        background: LabelBackground = .transparent,
        textColor: LabelColor = .white,
        sizeFraction: CGFloat = 0.10,
        position: CGPoint = CGPoint(x: 0.5, y: 0.5)
    ) {
        self.text = text
        self.font = font
        self.background = background
        self.textColor = textColor
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

/// 라벨 글꼴 선택. `.memoment` 은 신규 번들 폰트 `MemomentKkukkukk.ttf`("꾸꾸"), `.system` 은 기본 시스템 폰트.
public enum LabelFont: String, Sendable, CaseIterable, Codable {
    case memoment
    case system
    public var displayName: String {
        switch self {
        case .memoment: "꾸꾸"
        case .system:   "기본"
        }
    }
}

/// 라벨 배경. 흰색 / 검정색 / 투명(배경 없음).
public enum LabelBackground: String, Sendable, CaseIterable, Codable {
    case white
    case black
    case transparent
    public var displayName: String {
        switch self {
        case .white:       "흰색"
        case .black:       "검정색"
        case .transparent: "투명"
        }
    }
}

/// 라벨 글자색. 흰색 / 검정색.
public enum LabelColor: String, Sendable, CaseIterable, Codable {
    case white
    case black
    public var displayName: String {
        switch self {
        case .white: "흰색"
        case .black: "검정색"
        }
    }
}
