import SwiftUI

public extension View {
    /// 사진집 화면의 공통 배경.
    func chalNaScreen() -> some View {
        self.background(ChalNaColor.bg.ignoresSafeArea())
    }
}
