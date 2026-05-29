import CoreGraphics

/// 라벨 9구역 위치. CoreAnimation 좌표계(좌하단 원점) origin 계산을 포함한 순수 모델.
public enum LabelPosition: Int, CaseIterable, Sendable, Codable {
    case topLeft, topCenter, topRight
    case centerLeft, center, centerRight
    case bottomLeft, bottomCenter, bottomRight

    /// 사용자 표기. 예: .center → "정중앙"
    public var koreanName: String {
        switch self {
        case .topLeft:      return "좌측 상단"
        case .topCenter:    return "중앙 상단"
        case .topRight:     return "우측 상단"
        case .centerLeft:   return "좌측 중앙"
        case .center:       return "정중앙"
        case .centerRight:  return "우측 중앙"
        case .bottomLeft:   return "좌측 하단"
        case .bottomCenter: return "중앙 하단"
        case .bottomRight:  return "우측 하단"
        }
    }

    /// 가로 정렬: 0 = left, 0.5 = center, 1 = right
    public var horizontalAnchor: CGFloat {
        switch self {
        case .topLeft, .centerLeft, .bottomLeft:    return 0
        case .topCenter, .center, .bottomCenter:    return 0.5
        case .topRight, .centerRight, .bottomRight: return 1
        }
    }

    /// 세로 정렬(CoreAnimation, 좌하단 원점): 1 = top, 0.5 = middle, 0 = bottom
    public var verticalAnchor: CGFloat {
        switch self {
        case .topLeft, .topCenter, .topRight:          return 1
        case .centerLeft, .center, .centerRight:       return 0.5
        case .bottomLeft, .bottomCenter, .bottomRight: return 0
        }
    }

    /// 텍스트의 좌하단 origin (CoreAnimation). padding 안쪽으로 클램프해 코너에서도 캔버스 밖으로 안 나간다.
    public func origin(renderSize: CGSize, textSize: CGSize, padding: CGSize) -> CGPoint {
        let minX = padding.width
        let maxX = max(minX, renderSize.width - padding.width - textSize.width)
        let minY = padding.height
        let maxY = max(minY, renderSize.height - padding.height - textSize.height)
        let x = minX + (maxX - minX) * horizontalAnchor
        let y = minY + (maxY - minY) * verticalAnchor
        return CGPoint(x: x, y: y)
    }
}

/// 라벨 표시/위치 설정 묶음. 렌더러로 전달되는 값 타입.
public struct LabelSettings: Equatable, Sendable {
    public var timeEnabled: Bool
    public var timePosition: LabelPosition
    public var dateEnabled: Bool
    public var datePosition: LabelPosition

    public init(
        timeEnabled: Bool = true,
        timePosition: LabelPosition = .center,
        dateEnabled: Bool = true,
        datePosition: LabelPosition = .bottomCenter
    ) {
        self.timeEnabled = timeEnabled
        self.timePosition = timePosition
        self.dateEnabled = dateEnabled
        self.datePosition = datePosition
    }

    public static let `default` = LabelSettings()
}

/// 설정 UI/네비게이션에서 어떤 라벨을 다루는지 식별.
public enum LabelKind: String, CaseIterable, Sendable, Hashable {
    case time, date

    public var title: String {
        switch self {
        case .time: return "시각 라벨"
        case .date: return "날짜 라벨"
        }
    }

    public var subtitle: String {
        switch self {
        case .time: return "HH:mm"
        case .date: return "yyyy/MM/dd"
        }
    }

    public var sampleText: String {
        switch self {
        case .time: return "12:30"
        case .date: return "2026/04/05"
        }
    }
}
