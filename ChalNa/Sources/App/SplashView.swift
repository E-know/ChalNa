import SwiftUI
import DesignSystem

/// 앱 시작 시 앱 아이콘을 페이드+확대로 보여주는 스플래시.
/// 순수 표현·일회성이라 TCA 상태 없이 로컬 @State 로만 동작.
///
/// 배경은 `bg`(본문과 동일) + 아이콘 뒤 `brandDeep` 라디얼 글로우다.
/// brandDeep 풀배경이면 본문(bg)으로 넘어갈 때 밝기가 급변한다.
struct SplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        ZStack {
            // 브랜드 색 라디얼 글로우 — 스플래시가 이미 본문의 어둠 위에 있게 한다.
            // 반경은 짧은 변 기준 비례(0.62)로 잡아 기기 크기와 무관하게
            // 가장자리에 `bg` 가 남도록 한다(고정값 320은 SE 에서 풀블리드 워시가 됨).
            GeometryReader { proxy in
                RadialGradient(
                    colors: [ChalNaColor.brandDeep.opacity(0.55), ChalNaColor.bg],
                    center: .center,
                    startRadius: 0,
                    endRadius: min(proxy.size.width, proxy.size.height) * 0.62
                )
                .ignoresSafeArea()
            }

            VStack(spacing: 16) {
                Image("splash_icon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)

                VStack(spacing: 2) {
                    Text(verbatim: "찰나")
                        .font(ChalNaTypography.fixed(48))
                    Text(verbatim: "ChalNa")
                        .font(ChalNaTypography.fixed(24))
                }
                .foregroundStyle(ChalNaColor.textPrimary)
            }
            .scaleEffect(scale)
            .opacity(appeared ? 1 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ChalNaColor.bg.ignoresSafeArea())
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { appeared = true }
        }
    }

    /// Reduce Motion 시 확대 생략(페이드만).
    private var scale: CGFloat {
        if reduceMotion { return 1 }
        return appeared ? 1.0 : 0.92
    }
}

#Preview {
    SplashView()
}
