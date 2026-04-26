import SwiftUI

/// Coral 이중 외곽선 + 모노 대문자 텍스트 + 회전 스탬프.
public struct StampBadge: View {
    public var text: String
    public var angle: Double

    public init(_ text: String, angle: Double = -8) {
        self.text = text
        self.angle = angle
    }

    public var body: some View {
        ZStack {
            // Ghost offset
            frame(opacity: 0.35)
                .offset(x: 3, y: 2)
            frame(opacity: 0.85)
        }
        .rotationEffect(.degrees(angle))
    }

    private func frame(opacity: Double) -> some View {
        Text(text.uppercased())
            .font(MomentsTypography.monoFallback(11, weight: .bold))
            .tracking(1.0)
            .foregroundColor(MomentsColor.coral.opacity(opacity))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(MomentsColor.coral.opacity(opacity), lineWidth: 2)
            )
    }
}

#Preview {
    HStack(spacing: 24) {
        StampBadge("Draft · v0.1")
        StampBadge("Keep · Analog", angle: 4)
    }
    .padding(32)
    .background(MomentsColor.cream)
}
