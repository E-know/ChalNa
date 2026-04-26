import SwiftUI

/// 손글씨 톤의 한 줄 안내 / 힌트 텍스트.
/// 아이콘을 앞에 달 수 있고, 색상은 `taupe` 또는 `coral`로 맥락을 표현.
public struct HandNoteRow: View {
    public enum Tone {
        case muted     // taupe — 비강조 안내
        case accent    // coral — 액션 유도
    }

    public var text: String
    public var icon: MomentsIconKind?
    public var tone: Tone
    public var size: CGFloat
    public var alignment: HorizontalAlignment

    public init(
        _ text: String,
        icon: MomentsIconKind? = nil,
        tone: Tone = .muted,
        size: CGFloat = 17,
        alignment: HorizontalAlignment = .center
    ) {
        self.text = text
        self.icon = icon
        self.tone = tone
        self.size = size
        self.alignment = alignment
    }

    public var body: some View {
        HStack(spacing: MomentsSpacing.xs) {
            if let icon {
                MomentsIcon(icon, size: size * 0.82)
                    .foregroundColor(color)
            }
            Text(text)
                .font(MomentsTypography.handFallback(size))
                .foregroundColor(color)
                .multilineTextAlignment(alignment == .center ? .center : .leading)
        }
        .frame(maxWidth: .infinity, alignment: alignment == .center ? .center : .leading)
    }

    private var color: Color {
        switch tone {
        case .muted:  return MomentsColor.taupe
        case .accent: return MomentsColor.coral
        }
    }
}

#Preview {
    VStack(spacing: MomentsSpacing.md) {
        HandNoteRow("클립을 탭해 편집 · 길게 눌러 이동")
        HandNoteRow("여기에 놓으면 09.15 사이에 들어가요 ✦", tone: .accent, size: 18)
        HandNoteRow("저장되었어요", icon: .check, tone: .accent, size: 17, alignment: .leading)
    }
    .padding(MomentsSpacing.xl)
    .background(MomentsColor.cream)
}
