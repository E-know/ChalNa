import SwiftUI
import UIKit
import Models
import DesignSystem

/// ClipLabel 한 개를 스타일(폰트·글자색·배경)대로 그리는 공용 텍스트 뷰.
/// 라벨 에디터와 타임라인 미리보기가 공유한다. 위치/드래그는 호출 측 담당.
/// `fontPx` = 표시 박스 높이 × clampedSizeFraction.
/// 텍스트 박스를 합성(CATextLayer)과 동일한 UIFont 측정값으로 고정해, `.position` 중심 기준을 영상 출력과 맞춘다.
struct ClipLabelText: View {
    let label: ClipLabel
    let fontPx: CGFloat
    var placeholder: Bool = false

    private var displayString: String { placeholder ? "라벨 입력" : label.text }

    private var textColor: Color {
        label.textColor == .white ? .white : .black
    }

    /// 합성 measureCustomText 와 동일한 UIFont 로 측정한 텍스트 크기.
    private var measuredSize: CGSize {
        let ui: UIFont = label.font == .memoment
            ? ChalNaTypography.memomentUIFont(fontPx)
            : .systemFont(ofSize: fontPx, weight: .semibold)
        let s = NSAttributedString(string: displayString, attributes: [.font: ui]).size()
        return CGSize(width: ceil(s.width), height: ceil(s.height))
    }

    private var styledText: some View {
        Text(displayString)
            .font(label.font == .memoment
                  ? ChalNaTypography.memoment(fontPx)
                  : ChalNaTypography.krBody(fontPx, weight: .semibold))
            .lineLimit(1)
            .fixedSize()
            .frame(width: measuredSize.width, height: measuredSize.height)
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
