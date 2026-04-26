import SwiftUI
import DesignSystem

/// HTML 프로토타입의 `.th-*` 클래스에 대응하는 따뜻한 여행 톤 썸네일 프리셋.
public enum ThumbnailPreset: String, CaseIterable, Hashable, Sendable {
    case jejuSea        // 제주 바다 — denim/blue
    case jejuOrange     // 제주 오렌지 노을
    case hallasan       // 한라산 sage 그린
    case tokyoNeon      // 도쿄 네온 퍼플→코랄
    case seoulSun       // 서울 황금빛
    case beach          // 흐린 해변 블루그레이
    case street         // 거리 베이지 tan
    case night          // 밤 퍼플→코랄
    case forest         // 짙은 숲
    case sunset         // 강렬한 코랄 노을
    case field          // 풀밭 샌드톤
    case cafe           // 따뜻한 카페 브라운

    @ViewBuilder
    public func view() -> some View {
        ZStack {
            LinearGradient(colors: gradientStops, startPoint: start, endPoint: end)
            ForEach(Array(highlights.enumerated()), id: \.offset) { _, hi in
                RadialGradient(
                    colors: [hi.color, .clear],
                    center: hi.center,
                    startRadius: 0,
                    endRadius: hi.radius
                )
            }
        }
    }

    // MARK: - Recipes

    private var gradientStops: [Color] {
        switch self {
        case .jejuSea:      return [Color(hex: 0xBFD5E2), Color(hex: 0x7A92A8), Color(hex: 0x4B6374)]
        case .jejuOrange:   return [Color(hex: 0xF3C9A8), Color(hex: 0xC98B72)]
        case .hallasan:     return [Color(hex: 0xA8B89E), Color(hex: 0x6E8C77), Color(hex: 0x3D5240)]
        case .tokyoNeon:    return [Color(hex: 0x3B3048), Color(hex: 0x7A5A7F), Color(hex: 0xD98977)]
        case .seoulSun:     return [Color(hex: 0xF5D098), Color(hex: 0xB87E4A)]
        case .beach:        return [Color(hex: 0xA8C3D2), Color(hex: 0x5F7E8E)]
        case .street:       return [Color(hex: 0xD8C8AC), Color(hex: 0x9B8468)]
        case .night:        return [Color(hex: 0x2A2136), Color(hex: 0x463656), Color(hex: 0xE8A598)]
        case .forest:       return [Color(hex: 0x3D5240), Color(hex: 0x253327)]
        case .sunset:       return [Color(hex: 0xE8A598), Color(hex: 0x8B4A3F)]
        case .field:        return [Color(hex: 0xC9B9A0), Color(hex: 0x8D7A61)]
        case .cafe:         return [Color(hex: 0xD8B79A), Color(hex: 0x956D50)]
        }
    }

    private var start: UnitPoint {
        switch self {
        case .jejuSea, .hallasan, .field, .sunset, .night, .forest, .seoulSun: return .top
        case .jejuOrange, .street, .cafe:                                      return UnitPoint(x: 0.05, y: 0)
        case .tokyoNeon, .beach:                                               return UnitPoint(x: 0.1, y: 0)
        }
    }

    private var end: UnitPoint {
        switch self {
        case .jejuSea, .hallasan, .field, .sunset, .night, .forest, .seoulSun: return .bottom
        case .jejuOrange, .street, .cafe:                                      return UnitPoint(x: 1.0, y: 1.0)
        case .tokyoNeon, .beach:                                               return UnitPoint(x: 0.9, y: 1.0)
        }
    }

    private struct Highlight {
        let color: Color
        let center: UnitPoint
        let radius: CGFloat
    }

    private var highlights: [Highlight] {
        switch self {
        case .jejuSea:    return [.init(color: Color(hex: 0xF7DDC3).opacity(0.55), center: .init(x: 0.3, y: 0.2), radius: 120)]
        case .jejuOrange: return [
            .init(color: Color(hex: 0xF7DDC3).opacity(0.6),  center: .init(x: 0.3, y: 0.25), radius: 120),
            .init(color: Color(hex: 0xE8A598).opacity(0.55), center: .init(x: 0.75, y: 0.8), radius: 140)
        ]
        case .hallasan:   return [.init(color: Color(hex: 0xFFE6B8).opacity(0.55), center: .init(x: 0.7, y: 0.22), radius: 110)]
        case .tokyoNeon:  return [.init(color: Color(hex: 0xE8A598).opacity(0.5), center: .init(x: 0.6, y: 0.75), radius: 130)]
        case .seoulSun:   return [.init(color: Color(hex: 0xFFF3D4).opacity(0.55), center: .init(x: 0.8, y: 0.3), radius: 130)]
        case .beach:      return [.init(color: Color(hex: 0xCCDCE8).opacity(0.6), center: .init(x: 0.2, y: 0.8), radius: 140)]
        case .street:     return [.init(color: Color(hex: 0xE6E0CF).opacity(0.6), center: .init(x: 0.3, y: 0.7), radius: 150)]
        case .night:      return []
        case .forest:     return [.init(color: Color(hex: 0xA8B89E).opacity(0.5), center: .init(x: 0.5, y: 0.2), radius: 110)]
        case .sunset:     return [.init(color: Color(hex: 0xFFE2A8).opacity(0.55), center: .init(x: 0.7, y: 0.3), radius: 130)]
        case .field:      return [.init(color: Color(hex: 0xF2D7C3).opacity(0.55), center: .init(x: 0.5, y: 0.3), radius: 140)]
        case .cafe:       return [.init(color: Color(hex: 0xF8E5CF).opacity(0.6), center: .init(x: 0.3, y: 0.4), radius: 140)]
        }
    }
}
