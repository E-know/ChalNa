import SwiftUI

/// Danawa DDS Mobile 텍스트필드 (단일 라인 + 라벨 + helper/error 상태).
public struct ChalNaTextField: View {
    public let label: String?
    public let placeholder: String
    public let helper: String?
    public let errorText: String?
    @Binding public var text: String
    @FocusState private var isFocused: Bool

    public init(
        label: String? = nil,
        placeholder: String = "",
        helper: String? = nil,
        errorText: String? = nil,
        text: Binding<String>
    ) {
        self.label = label
        self.placeholder = placeholder
        self.helper = helper
        self.errorText = errorText
        self._text = text
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let label {
                Text(label)
                    .font(ChalNaTypography.label)
                    .foregroundColor(ChalNaColor.textPrimary)
            }

            TextField("", text: $text, prompt: Text(verbatim: placeholder)
                .foregroundColor(ChalNaColor.textTertiary))
                .tint(ChalNaColor.accent)
                .focused($isFocused)
                .font(ChalNaTypography.body)
                .foregroundColor(ChalNaColor.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: ChalNaRadius.sm, style: .continuous)
                        .fill(ChalNaColor.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: ChalNaRadius.sm, style: .continuous)
                        .strokeBorder(borderColor, lineWidth: borderWidth)
                )

            if let errorText {
                Text(errorText)
                    .font(ChalNaTypography.caption)
                    .foregroundColor(ChalNaColor.danger)
            } else if let helper {
                Text(helper)
                    .font(ChalNaTypography.caption)
                    .foregroundColor(ChalNaColor.textSecondary)
            }
        }
    }

    private var borderColor: Color {
        if errorText != nil { return ChalNaColor.danger }
        return isFocused ? ChalNaColor.accent : ChalNaColor.borderStrong
    }

    private var borderWidth: CGFloat {
        (isFocused || errorText != nil) ? 1.5 : 1
    }
}

#Preview {
    @Previewable @State var title = ""
    @Previewable @State var failing = "유효하지 않은 입력"
    return VStack(spacing: 16) {
        ChalNaTextField(label: "필름 제목", placeholder: "예: 제주도, 우리의 봄", helper: "비워두면 자동으로 채워져요.", text: $title)
        ChalNaTextField(label: "Error 상태", placeholder: "값을 입력하세요", errorText: "30자 이내로 입력해 주세요.", text: $failing)
    }
    .padding(24)
    .background(ChalNaColor.bg)
}
