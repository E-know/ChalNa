import SwiftUI

/// 다크용 태그. 반투명 흰 필 + 선택적 글리프.
/// 구 `ChalNaChip` 이 내부에서 SF Symbols 를 직접 쓰며 만든 이중 아이콘 계통을 없앤다.
public enum ChalNaTagVariant {
    /// Live Photo. danger 계열 dot — Live Photo 의 붉은 계열 관례.
    case live
    /// 일반 영상.
    case video
    /// 정보성 (클립 수 · 길이 등).
    case neutral
    /// 선택 상태 · 강조.
    case accent
}

public struct ChalNaTag: View {
    public let label: String
    public let variant: ChalNaTagVariant
    public let icon: ChalNaIconKind?

    public init(_ label: String, variant: ChalNaTagVariant = .neutral, icon: ChalNaIconKind? = nil) {
        self.label = label
        self.variant = variant
        self.icon = icon
    }

    public var body: some View {
        HStack(spacing: 5) {
            leadingGlyph
            Text(verbatim: label)
                .font(ChalNaTypography.label)
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .foregroundColor(foreground)
        .background(Capsule(style: .continuous).fill(background))
        .overlay(Capsule(style: .continuous).strokeBorder(borderColor, lineWidth: 1))
    }

    @ViewBuilder
    private var leadingGlyph: some View {
        switch variant {
        case .live:
            Circle()
                .fill(ChalNaColor.danger)
                .frame(width: 7, height: 7)
        default:
            if let icon {
                ChalNaIcon(icon, size: 11, weight: .semibold)
            }
        }
    }

    private var background: Color {
        switch variant {
        case .live, .video, .neutral: return Color.white.opacity(0.10)
        case .accent:                 return ChalNaColor.accentFill.opacity(0.22)
        }
    }

    private var foreground: Color {
        switch variant {
        case .live, .video, .neutral: return ChalNaColor.textPrimary
        case .accent:                 return ChalNaColor.accent
        }
    }

    private var borderColor: Color {
        switch variant {
        case .accent: return ChalNaColor.accent.opacity(0.45)
        default:      return Color.white.opacity(0.08)
        }
    }
}

#Preview {
    HStack(spacing: 8) {
        ChalNaTag("LIVE", variant: .live)
        ChalNaTag("VIDEO", variant: .video, icon: .video)
        ChalNaTag("8 CLIPS", variant: .neutral)
        ChalNaTag("선택됨", variant: .accent, icon: .check)
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ChalNaColor.bg)
}
