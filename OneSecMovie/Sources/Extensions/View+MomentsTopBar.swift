import SwiftUI

public extension View {
    /// NavigationBar 역할의 커스텀 헤더를 화면 최상단에 고정한다.
    /// 배경은 완전 투명 — `momentsScreen()` 의 cream + grain + vignette 가 그대로 비친다.
    ///
    /// - Parameter scrollsBehind:
    ///   - `true` 면 ScrollView 컨텐츠가 헤더 뒤로 스크롤된다 (Home, MediaPicker).
    ///     `overlay(alignment:.top)` 로 헤더를 띄우고 `contentMargins(.top:for:.scrollContent)`
    ///     로 스크롤 컨텐츠의 초기 오프셋을 헤더 높이만큼 잡아 첫 컨텐츠는 헤더 아래에서 시작.
    ///   - `false` (기본) 면 `safeAreaInset(edge:.top)` 로 헤더 높이만큼 안전 영역을 차지해
    ///     컨텐츠가 헤더 뒤로 들어가지 않는다 (Timeline, Export 같은 고정 레이아웃용).
    func momentsTopBar<Bar: View>(
        scrollsBehind: Bool = false,
        @ViewBuilder _ bar: () -> Bar
    ) -> some View {
        modifier(MomentsTopBarModifier(scrollsBehind: scrollsBehind, bar: bar()))
    }
}

private struct MomentsTopBarModifier<Bar: View>: ViewModifier {
    let scrollsBehind: Bool
    let bar: Bar

    @State private var barHeight: CGFloat = 0

    @ViewBuilder
    func body(content: Content) -> some View {
        if scrollsBehind {
            content
                .contentMargins(.top, barHeight, for: .scrollContent)
                .overlay(alignment: .top) {
                    barView
                        .background(
                            GeometryReader { geo in
                                Color.clear
                                    .preference(key: MomentsTopBarHeightKey.self, value: geo.size.height)
                            }
                        )
                }
                .onPreferenceChange(MomentsTopBarHeightKey.self) { newHeight in
                    barHeight = newHeight
                }
        } else {
            content.safeAreaInset(edge: .top, spacing: 0) {
                barView
            }
        }
    }

    private var barView: some View {
        bar
            .padding(.horizontal, MomentsSpacing.md + 4)
            .padding(.vertical, MomentsSpacing.sm)
            .frame(maxWidth: .infinity)
        // 배경 없음 — 완전 투명. 화면의 cream + paperGrain + vignette 가 비친다.
    }
}

private struct MomentsTopBarHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
