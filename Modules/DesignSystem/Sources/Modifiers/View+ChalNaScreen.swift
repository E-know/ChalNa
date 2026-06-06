import SwiftUI

public extension View {
    /// 다나와 DDS Mobile 표준 화면 배경.
    /// (구버전의 paperGrain / vignette 오버레이는 제거됨)
    func chalNaScreen() -> some View {
        self.background(Color.white.ignoresSafeArea())
    }
}
