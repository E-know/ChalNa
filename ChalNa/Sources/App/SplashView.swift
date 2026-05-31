import SwiftUI
import DesignSystem

/// 앱 시작 시 앱 아이콘을 페이드+확대로 보여주는 스플래시.
/// 순수 표현·일회성이라 TCA 상태 없이 로컬 @State 로만 동작.
struct SplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    /// 앱 Info.plist UIAppFonts 에 등록된 KERISKEDU 아웃라인 폰트의 PostScript name.
    private static let kerisFontName = "KERISKEDUOTF_Line"

    var body: some View {
        ZStack {
            VStack(spacing: 16) {
                Image("SplashIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    // iOS 홈 화면 아이콘 스퀴클 마스크 비율(≈0.2237 × 120pt). UI 반경이 아닌 플랫폼 유래 값.
                    .clipShape(RoundedRectangle(cornerRadius: 27, style: .continuous))
                    .chalNaShadow(ChalNaShadow.md)

                // 앱 브랜드 라벨 — 앱에 등록된 KERISKEDU(영상 오버레이와 동일 패밀리).
                VStack(spacing: 2) {
                    Text("찰나")
                        .font(.custom(Self.kerisFontName, size: 32))
                    Text("ChalNa")
                        .font(.custom(Self.kerisFontName, size: 15))
                }
                .foregroundStyle(ChalNaColor.ink)
            }
            // Reduce Motion 시 확대 생략(페이드만)
            .scaleEffect(scale)
            .opacity(appeared ? 1 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .chalNaScreen()
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { appeared = true }
        }
    }

    private var scale: CGFloat {
        if reduceMotion { return 1 }
        return appeared ? 1.0 : 0.92
    }
}

#Preview {
    SplashView()
}
