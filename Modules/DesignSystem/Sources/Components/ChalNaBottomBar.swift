import SwiftUI

/// 화면 하단 고정 액션 영역. `safeAreaInset(edge: .bottom)` 에 넣어 쓴다.
///
/// 여백·배경·상단 hairline·세이프에어리어 처리를 한 곳에서 결정한다 —
/// Home CTA · MediaPicker 확인바 · Export CTA · LabelEditor 슬라이더가 공유한다.
public struct ChalNaBottomBar<Content: View>: View {
    private let content: () -> Content

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    public var body: some View {
        content()
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 10)
            .background(ChalNaColor.bg.ignoresSafeArea(edges: .bottom))
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(ChalNaColor.border)
                    .frame(height: 1)
            }
    }
}

#Preview {
    VStack {
        Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ChalNaColor.bg)
    .safeAreaInset(edge: .bottom) {
        ChalNaBottomBar {
            HStack(spacing: 10) {
                Button("취소") {}.buttonStyle(.chalNa(.secondary, size: .lg, fillWidth: true))
                Button("다음") {}.buttonStyle(.chalNa(.primary, size: .lg, fillWidth: true))
            }
        }
    }
}
