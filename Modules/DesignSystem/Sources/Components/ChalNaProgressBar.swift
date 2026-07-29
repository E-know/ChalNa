import SwiftUI

/// 진행률 바. Export 내보내기 진행률에 쓴다.
public struct ChalNaProgressBar: View {
    public let progress: Double
    public let tint: Color
    public let height: CGFloat

    public init(progress: Double, tint: Color = ChalNaColor.accent, height: CGFloat = 5) {
        self.progress = progress
        self.tint = tint
        self.height = height
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(ChalNaColor.border)
                Capsule()
                    .fill(tint)
                    .frame(width: max(0, proxy.size.width * clamped))
            }
        }
        .frame(height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("진행률")
        .accessibilityValue(Text(verbatim: "\(Int(clamped * 100))%"))
    }

    private var clamped: Double {
        guard progress.isFinite else { return 0 }
        return max(0, min(1, progress))
    }
}

#Preview {
    VStack(spacing: 20) {
        ChalNaProgressBar(progress: 0.0)
        ChalNaProgressBar(progress: 0.62)
        ChalNaProgressBar(progress: 1.0, tint: ChalNaColor.success)
        ChalNaProgressBar(progress: 0.4, tint: ChalNaColor.danger)
    }
    .padding(20)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ChalNaColor.bg)
}
