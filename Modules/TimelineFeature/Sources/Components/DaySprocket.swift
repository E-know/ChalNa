import SwiftUI
import DesignSystem

/// FilmStrip 의 날짜 구분자(필름 sprocket 스타일).
/// `MM.dd` 라벨 + sprocket dot 라인. UIKit 셀(`UIHostingConfiguration`)에서도 쓰이므로 internal.
struct DaySprocket: View {
    let label: String
    let highlighted: Bool

    var body: some View {
        VStack(spacing: 6) {
            Text(verbatim: label)
                .font(ChalNaTypography.label)
                .foregroundColor(highlighted ? ChalNaColor.accent : ChalNaColor.textSecondary)
            SprocketLine(highlighted: highlighted)
                .frame(width: 2, height: 64)
        }
        .padding(.horizontal, 2)
    }
}

private struct SprocketLine: View {
    let highlighted: Bool

    var body: some View {
        GeometryReader { proxy in
            let count = max(1, Int(proxy.size.height / 8))
            VStack(spacing: 3) {
                ForEach(0..<count, id: \.self) { _ in
                    Circle()
                        .fill(highlighted ? ChalNaColor.accent : ChalNaColor.border)
                        .frame(width: 2.2, height: 2.2)
                }
            }
            .frame(width: 2.2)
            .frame(maxHeight: .infinity)
        }
    }
}
