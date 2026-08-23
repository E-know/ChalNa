import SwiftUI

public extension View {
    /// 다크 시네마틱 표준 화면 배경.
    func chalNaScreen() -> some View {
        self.background(ChalNaColor.bg.ignoresSafeArea())
    }
}
