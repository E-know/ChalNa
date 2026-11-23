import SwiftUI
import DesignSystem

struct SplashView: View {
    var body: some View {
        Text(verbatim: "찰나")
            .font(ChalNaTypography.fixed(48))
            .foregroundStyle(ChalNaColor.textPrimary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .chalNaScreen()
    }
}
