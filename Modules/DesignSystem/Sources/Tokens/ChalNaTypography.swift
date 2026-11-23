import SwiftUI

/// iOS 내장 Apple SD Gothic Neo. UI 글자는 각 역할에 맞춰 Dynamic Type으로 확대한다.
public enum ChalNaTypography {
    public static let display = Font.custom("AppleSDGothicNeo-Bold", size: 36, relativeTo: .largeTitle)
    public static let screenTitle = Font.custom("AppleSDGothicNeo-Bold", size: 28, relativeTo: .title)
    public static let title = Font.custom("AppleSDGothicNeo-Bold", size: 22, relativeTo: .title2)
    public static let headline = Font.custom("AppleSDGothicNeo-Bold", size: 16, relativeTo: .headline)
    public static let body = Font.custom("AppleSDGothicNeo-Regular", size: 16, relativeTo: .body)
    public static let label = Font.custom("AppleSDGothicNeo-Medium", size: 14, relativeTo: .subheadline)
    public static let caption = Font.custom("AppleSDGothicNeo-Medium", size: 12, relativeTo: .caption)

    public enum Tracking {
        public static let title: CGFloat = -0.2
    }

    public static func fixed(_ size: CGFloat) -> Font {
        .custom("AppleSDGothicNeo-Bold", fixedSize: size)
    }
}
