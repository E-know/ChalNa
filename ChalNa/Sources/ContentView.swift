import SwiftUI
import DesignSystem

public struct ContentView: View {
    @State private var showSplash = true

    public init() {}

    public var body: some View {
        if AppMode.isShowcase {
            DesignSystemShowcaseView()
        } else {
            mainContent
        }
    }

    private var mainContent: some View {
        ZStack {
            // RootView 를 스플래시 뒤에서 미리 생성 → 페이드아웃 시 홈이 이미 준비됨.
            RootView()

            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation(.easeInOut(duration: 0.35)) { showSplash = false }
        }
    }
}

#Preview("App Root") {
    ContentView()
}

#Preview("Design System Showcase") {
    DesignSystemShowcaseView()
}
