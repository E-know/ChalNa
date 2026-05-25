import SwiftUI

/// Danawa DDS Mobile 텍스트필드 (단일 라인 + 라벨 + helper/error 상태).
public struct MomentsTextField: View {
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
                    .font(MomentsTypography.krBody(MomentsTypography.Size.small, weight: .medium))
                    .foregroundColor(MomentsColor.ink)
            }

            TextField(placeholder, text: $text)
                .focused($isFocused)
                .font(MomentsTypography.krBody(MomentsTypography.Size.body, weight: .regular))
                .foregroundColor(MomentsColor.ink)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: MomentsRadius.button, style: .continuous)
                        .fill(Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: MomentsRadius.button, style: .continuous)
                        .strokeBorder(borderColor, lineWidth: borderWidth)
                )

            if let errorText {
                Text(errorText)
                    .font(MomentsTypography.krBody(MomentsTypography.Size.caption))
                    .foregroundColor(MomentsColor.danger)
            } else if let helper {
                Text(helper)
                    .font(MomentsTypography.krBody(MomentsTypography.Size.caption))
                    .foregroundColor(MomentsColor.taupe)
            }
        }
    }

    private var borderColor: Color {
        if errorText != nil { return MomentsColor.danger }
        return isFocused ? MomentsColor.coral : MomentsColor.Gray.g200
    }

    private var borderWidth: CGFloat {
        (isFocused || errorText != nil) ? 1.5 : 1
    }
}

#Preview {
    @Previewable @State var title = ""
    @Previewable @State var failing = "유효하지 않은 입력"
    return VStack(spacing: 16) {
        MomentsTextField(label: "필름 제목", placeholder: "예: 제주도, 우리의 봄", helper: "비워두면 자동으로 채워져요.", text: $title)
        MomentsTextField(label: "Error 상태", placeholder: "값을 입력하세요", errorText: "30자 이내로 입력해 주세요.", text: $failing)
    }
    .padding(24)
    .background(MomentsColor.cream)
}
