import SwiftUI
import DesignSystem

/// FilmStrip의 날짜 구분자(필름 sprocket 스타일).
/// `MM.dd` 라벨 + 점선 같은 sprocket dot 라인. UIKit 셀(`UIHostingConfiguration`)에서도 사용 가능하도록 internal.
struct DaySprocket: View {
    let label: String
    let highlighted: Bool

    var body: some View {
        VStack(spacing: 6) {
            Text(label)
                .font(ChalNaTypography.handFallback(13))
                .foregroundColor(highlighted ? ChalNaColor.coral : ChalNaColor.cream)
            SprocketLine()
                .frame(width: 2, height: 64)
        }
        .opacity(highlighted ? 1.0 : 0.85)
        .padding(.horizontal, 2)
    }
}

private struct SprocketLine: View {
    var body: some View {
        GeometryReader { proxy in
            let count = max(1, Int(proxy.size.height / 8))
            VStack(spacing: 3) {
                ForEach(0..<count, id: \.self) { _ in
                    Circle()
                        .fill(ChalNaColor.cream)
                        .frame(width: 2.2, height: 2.2)
                }
            }
            .frame(width: 2.2)
            .frame(maxHeight: .infinity)
        }
    }
}
