import SwiftUI

public extension View {
    /// 크림 배경 + 페이퍼 그레인 + 비네트를 한 번에 입히는 화면 백그라운드.
    func momentsScreen(
        grainOpacity: Double = 0.28,
        vignette: Double = 0.08
    ) -> some View {
        self
            .background(MomentsColor.cream.ignoresSafeArea())
            .overlay(PaperGrainOverlay(opacity: grainOpacity))
            .overlay(Vignette(intensity: vignette))
    }
}
