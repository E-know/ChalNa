import SwiftUI

/// 멀티라인 입력. Support 화면의 `TextEditor` + 수동 플레이스홀더 오버레이를 대체한다.
public struct ChalNaTextArea: View {
    private let placeholder: String
    private let minHeight: CGFloat
    @Binding private var text: String
    @FocusState private var isFocused: Bool

    public init(placeholder: String, minHeight: CGFloat = 180, text: Binding<String>) {
        self.placeholder = placeholder
        self.minHeight = minHeight
        self._text = text
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(verbatim: placeholder)
                    .font(ChalNaTypography.body)
                    .foregroundColor(ChalNaColor.textTertiary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $text)
                .scrollContentBackground(.hidden)
                .font(ChalNaTypography.body)
                .foregroundColor(ChalNaColor.textPrimary)
                .tint(ChalNaColor.accent)
                .focused($isFocused)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(minHeight: minHeight)
        }
        .background(
            RoundedRectangle(cornerRadius: ChalNaRadius.sm, style: .continuous)
                .fill(ChalNaColor.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ChalNaRadius.sm, style: .continuous)
                .strokeBorder(isFocused ? ChalNaColor.accent : ChalNaColor.borderStrong,
                              lineWidth: isFocused ? 1.5 : 1)
        )
        .animation(ChalNaMotion.fast, value: isFocused)
    }
}

#Preview {
    @Previewable @State var text = ""
    return ChalNaTextArea(placeholder: "불편한 점이나 제안을 자유롭게 적어주세요.", text: $text)
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ChalNaColor.bg)
}
