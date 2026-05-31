import SwiftUI
import Models
import DesignSystem

/// 라벨 텍스트만 입력하는 전체화면 포커스 모드(인스타 스토리 방식).
/// 클립 사진을 어둡게 깔고 가운데 큰 텍스트로 입력. 폰트는 라벨 선택값(WYSIWYG),
/// 가독성을 위해 입력 중 글자색은 흰색. 색/배경/크기/위치는 편집 화면 소관.
struct LabelTextInputView: View {
    let clip: Clip
    let font: LabelFont
    let onCommit: (String) -> Void
    let onCancel: () -> Void

    @State private var text: String
    @FocusState private var focused: Bool

    init(clip: Clip, initialText: String, font: LabelFont,
         onCommit: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.clip = clip
        self.font = font
        self.onCommit = onCommit
        self.onCancel = onCancel
        _text = State(initialValue: initialText)
    }

    var body: some View {
        ZStack {
            clip.thumbnailView(contentMode: .fill)
                .ignoresSafeArea()
                .overlay(Color.black.opacity(0.5).ignoresSafeArea())

            VStack(spacing: 0) {
                topBar
                Spacer()
                inputField
                Spacer()
            }
        }
        .task {
            try? await Task.sleep(for: .milliseconds(50))
            focused = true
        }
    }

    private var topBar: some View {
        HStack {
            Button("취소") { onCancel() }
                .font(ChalNaTypography.krBody(15, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
            Spacer()
            Button("완료") { onCommit(text) }
                .font(ChalNaTypography.krBody(15, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var inputField: some View {
        TextField(
            "",
            text: $text,
            prompt: Text("텍스트 입력").foregroundColor(.white.opacity(0.4))
        )
        .focused($focused)
        .multilineTextAlignment(.center)
        .lineLimit(1)
        .font(font == .memoment ? ChalNaTypography.memoment(36) : ChalNaTypography.krBody(36, weight: .semibold))
        .foregroundColor(.white)
        .tint(ChalNaColor.coral)
        .padding(.horizontal, 24)
        .submitLabel(.done)
        .onSubmit { onCommit(text) }
    }
}

#Preview {
    LabelTextInputView(
        clip: SampleData.jejuTimeline[0],
        initialText: "제주 바다",
        font: .memoment,
        onCommit: { _ in },
        onCancel: {}
    )
}
