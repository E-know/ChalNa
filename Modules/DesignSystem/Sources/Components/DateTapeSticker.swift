import SwiftUI

/// 가운데 이보리 배경 + 좌상/우하 테이프 장식이 붙은 날짜 스티커.
/// "2025.09.14 · 제주 첫날" 같은 캡션 표시용.
public struct DateTapeSticker: View {
    public var text: String
    public var rotationDegrees: Double
    public var leftTape: MaskingTapeTint?
    public var rightTape: MaskingTapeTint?
    public var muted: Bool

    public init(
        text: String,
        rotationDegrees: Double = -1.5,
        leftTape: MaskingTapeTint? = .coral,
        rightTape: MaskingTapeTint? = .sage,
        muted: Bool = false
    ) {
        self.text = text
        self.rotationDegrees = rotationDegrees
        self.leftTape = leftTape
        self.rightTape = rightTape
        self.muted = muted
    }

    public var body: some View {
        ZStack {
            Text(text)
                .font(MomentsTypography.monoFallback(11, weight: .medium))
                .tracking(1.4)
                .foregroundColor(MomentsColor.ink)
                .lineLimit(1)
                .padding(.horizontal, MomentsSpacing.md)
                .padding(.vertical, 6)
                .background(MomentsColor.ivory.opacity(0.95))
                .overlay(
                    Rectangle().stroke(MomentsColor.taupe.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: MomentsColor.ink.opacity(0.15), radius: 3, y: 2)
        }
        .overlay(alignment: .topLeading) {
            if let tint = leftTape {
                MaskingTape(width: 24, height: 12, tint: tint)
                    .rotationEffect(.degrees(-14))
                    .offset(x: -8, y: -6)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if let tint = rightTape {
                MaskingTape(width: 22, height: 12, tint: tint)
                    .rotationEffect(.degrees(10))
                    .offset(x: 8, y: 6)
            }
        }
        .rotationEffect(.degrees(rotationDegrees))
        .opacity(muted ? 0.5 : 1.0)
    }
}

#Preview {
    VStack(spacing: MomentsSpacing.lg) {
        DateTapeSticker(text: "2025.09.14 · 제주 첫날")
        DateTapeSticker(text: "2025.09.15 · 한라산", rotationDegrees: 1.5, leftTape: .sage, rightTape: .coral)
        DateTapeSticker(text: "2025.09.14 · 제주 첫날", muted: true)
    }
    .padding(MomentsSpacing.xl)
    .background(MomentsColor.cream)
}
