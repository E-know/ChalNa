import CoreGraphics
import Foundation

/// 사용자가 한 클립을 시계방향으로 90°씩 돌릴 때의 단계.
/// 한 번 탭 = `next()` 한 단계 → 4번 탭하면 원위치.
public enum ClipRotation: Int, Hashable, Sendable, CaseIterable {
    case r0 = 0
    case r90 = 90
    case r180 = 180
    case r270 = 270

    /// 다음 단계 (시계방향).
    public func next() -> ClipRotation {
        switch self {
        case .r0:   return .r90
        case .r90:  return .r180
        case .r180: return .r270
        case .r270: return .r0
        }
    }

    /// SwiftUI `.rotationEffect` 용 각도(°).
    public var degrees: Double { Double(rawValue) }

    /// 가로/세로 축이 swap되는 단계인지 (90°, 270°).
    public var swapsAxes: Bool { self == .r90 || self == .r270 }

    /// AVFoundation transform 용. 기준점을 원점으로 한 회전 행렬만 만들어 두고,
    /// 가운데 정렬 translate는 호출 측에서 합성한다.
    public var transform: CGAffineTransform {
        CGAffineTransform(rotationAngle: .pi * Double(rawValue) / 180.0)
    }
}
