import SwiftUI
import Models
import DesignSystem

/// ClipLabel 한 개를 스타일(폰트·글자색·배경)대로 그리는 공용 텍스트 뷰.
/// 라벨 에디터와 타임라인 미리보기가 공유한다. 위치/드래그는 호출 측 담당.
/// `fontPx` = 표시 박스 높이 × clampedSizeFraction.
struct ClipLabelText: View {
    let label: ClipLabel
    let fontPx: CGFloat
    /// 에디터의 빈 입력 상태에서 placeholder("라벨 입력")를 흐리게 표시할지.
    var placeholder: Bool = false

    private var textColor: Color {
        label.textColor == .white ? .white : .black
    }

    private var styledText: some View {
        Text(placeholder ? "라벨 입력" : label.text)
            .font(label.font == .memoment
                  ? ChalNaTypography.memoment(fontPx)
                  : ChalNaTypography.krBody(fontPx, weight: .semibold))
            .lineLimit(1)
            .fixedSize()
            .foregroundColor(placeholder ? textColor.opacity(0.6) : textColor)
    }

    @ViewBuilder
    var body: some View {
        switch label.background {
        case .transparent:
            styledText
        case .white, .black:
            styledText
                .padding(.horizontal, fontPx * 0.35)
                .padding(.vertical, fontPx * 0.22)
                .background(
                    RoundedRectangle(cornerRadius: min(fontPx * 0.4, 12), style: .continuous)
                        .fill(label.background == .white ? Color.white : Color.black)
                )
        }
    }
}
