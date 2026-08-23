import SwiftUI
import UIKit
import Models
import DesignSystem

/// ClipLabel 한 개를 박스 자막 스타일(흰 배경·검정 글씨·검정 테두리)로 그리는 공용 텍스트 뷰.
/// 자막 에디터와 타임라인 미리보기가 공유한다. 위치/드래그는 호출 측 담당.
/// `fontPx` = 표시 박스 높이 × clampedSizeFraction.
/// 텍스트 박스를 합성(CATextLayer)과 동일한 UIFont 측정값·박스 스타일(ClipLabel.BoxStyle)로 고정해,
/// `.position` 중심 기준과 박스 외형을 영상 출력과 맞춘다.
struct ClipLabelText: View {
    let label: ClipLabel
    let fontPx: CGFloat
    var placeholder: Bool = false

    private var displayString: String { placeholder ? String(localized: "자막 입력") : label.text }

    /// 합성 measureCustomText 와 동일한 UIFont(시스템 light) 로 측정한 텍스트 크기.
    private var measuredSize: CGSize {
        let ui = UIFont.systemFont(ofSize: fontPx, weight: .light)
        let s = NSAttributedString(string: displayString, attributes: [
            .font: ui,
            .kern: ClipLabel.BoxStyle.letterSpacing(for: fontPx),
        ]).size()
        return CGSize(width: ceil(s.width), height: ceil(s.height))
    }

    private var styledText: some View {
        Text(displayString)
            // 다크 토큰 적용 예외: 합성(CATextLayer)과 동일한 UIFont(systemFont, ofSize: fontPx)로
            // 픽셀 일치해야 하므로 역할 토큰(krBody 삭제됨) 대신 직접 시스템 폰트를 쓴다.
            // `scripts/design-lint.sh` 규칙 1 예외에 이 파일이 등록돼 있다.
            .font(.system(size: fontPx, weight: .light))
            .tracking(ClipLabel.BoxStyle.letterSpacing(for: fontPx))
            .lineLimit(1)
            .fixedSize()
            .frame(width: measuredSize.width, height: measuredSize.height)
            .foregroundColor(placeholder ? .black.opacity(0.5) : .black)
    }

    var body: some View {
        styledText.boxSubtitleStyle(fontPx: fontPx)
    }
}

/// 박스 자막 배경(흰 배경 + 검정 테두리 + 패딩). 표시(ClipLabelText)와 인라인 편집(TextField)이 공유한다.
struct BoxSubtitleStyle: ViewModifier {
    let fontPx: CGFloat
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, fontPx * ClipLabel.BoxStyle.horizontalPaddingFraction)
            .padding(.vertical, fontPx * ClipLabel.BoxStyle.verticalPaddingFraction)
            .background(Rectangle().fill(Color.white))
            .overlay(
                Rectangle()
                    .strokeBorder(Color.black, lineWidth: fontPx * ClipLabel.BoxStyle.borderWidthFraction)
            )
    }
}

extension View {
    /// 박스 자막 스타일(흰 배경 + 검정 테두리)을 적용한다.
    func boxSubtitleStyle(fontPx: CGFloat) -> some View {
        modifier(BoxSubtitleStyle(fontPx: fontPx))
    }
}
