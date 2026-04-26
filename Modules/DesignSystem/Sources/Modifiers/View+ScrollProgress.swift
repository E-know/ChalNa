import SwiftUI

/// ScrollView 내부 콘텐츠 최상단의 Y 오프셋을 부모로 publish하는 PreferenceKey.
/// 양수가 클수록 콘텐츠가 위로 밀려 올라간 것 — 헤더-본문 분리 진행도로 사용.
public struct ScrollOffsetPreferenceKey: PreferenceKey {
    public static var defaultValue: CGFloat = 0
    public static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

public extension View {
    /// ScrollView 내부 콘텐츠의 **첫 자식**에 부착한다.
    /// 부모 ScrollView가 `coordinateSpace(name:)`을 등록해 두면,
    /// 본 modifier가 해당 공간 기준 minY의 부호를 뒤집어 publish한다.
    /// (콘텐츠가 위로 밀려나면 minY는 음수 → 부호 반전 후 양수 offset).
    func trackScrollOffset(in coordinateSpace: String) -> some View {
        background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: ScrollOffsetPreferenceKey.self,
                    value: -geo.frame(in: .named(coordinateSpace)).minY
                )
            }
        )
    }
}
