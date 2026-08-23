import SwiftUI
import UIKit
import Models
import DesignSystem

/// 박스 자막 색 팔레트.
///
/// **다크 토큰 적용 예외.** 이 색들은 합성(`CATextLayer`/`CALayer`)이 쓰는 `UIColor` 와
/// 픽셀 단위로 일치해야 하므로 역할 토큰(테마·Dynamic Type 따라 변함)을 쓸 수 없다.
/// `scripts/design-lint.sh` 규칙 4(흰색)·5(검정) 예외에 **이 파일만** 등록돼 있고,
/// 라벨 박스의 색 리터럴은 여기 한곳에만 둔다 — `LabelEditorView` 는 이 헬퍼를 호출해
/// 리터럴을 갖지 않는다(파일 단위 예외를 늘리지 않기 위함).
enum ClipLabelBoxPalette {
    /// 글자색. 배경 ON = 검정(흰 박스 위), OFF = 흰색(영상 위 직접).
    /// 합성 `makeCustomLabelLayers` 의 `foregroundColor` 분기와 같은 규칙이다.
    static func foreground(hasBackground: Bool, placeholder: Bool) -> Color {
        let base: Color = hasBackground ? .black : .white
        return placeholder ? base.opacity(0.5) : base
    }

    /// 배경 박스 면색 (합성 `bgLayer.backgroundColor`).
    static let boxFill = Color.white
    /// 배경 박스 테두리색 (합성 `bgLayer.borderColor`).
    static let boxBorder = Color.black
}

/// ClipLabel 한 개를 박스 자막 스타일로 그리는 공용 텍스트 뷰.
/// `label.hasBackground` 가 true 면 흰 배경·검정 글씨·검정 테두리, false 면 흰 글씨만.
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
            .foregroundColor(ClipLabelBoxPalette.foreground(
                hasBackground: label.hasBackground, placeholder: placeholder
            ))
    }

    var body: some View {
        styledText.boxSubtitleStyle(fontPx: fontPx, hasBackground: label.hasBackground)
    }
}

/// 박스 자막 배경(흰 면 + 검정 테두리 + 패딩). 표시(ClipLabelText)와 인라인 편집(TextField)이 공유한다.
/// `hasBackground == false` 면 면·테두리를 그리지 않는다.
struct BoxSubtitleStyle: ViewModifier {
    let fontPx: CGFloat
    let hasBackground: Bool

    func body(content: Content) -> some View {
        content
            // 패딩은 배경 ON/OFF 에서 **동일**하다. 바뀌면 박스 크기가 달라져
            // ClipLabel.position(박스 중심) 역산이 어긋나고 토글마다 라벨이 움직인다.
            // 합성(makeCustomLabelLayers)도 같은 이유로 textLayer.frame 을 그대로 둔다.
            .padding(.horizontal, fontPx * ClipLabel.BoxStyle.horizontalPaddingFraction)
            .padding(.vertical, fontPx * ClipLabel.BoxStyle.verticalPaddingFraction)
            .background {
                if hasBackground {
                    Rectangle().fill(ClipLabelBoxPalette.boxFill)
                }
            }
            .overlay {
                if hasBackground {
                    Rectangle().strokeBorder(
                        ClipLabelBoxPalette.boxBorder,
                        lineWidth: fontPx * ClipLabel.BoxStyle.borderWidthFraction
                    )
                }
            }
    }
}

extension View {
    /// 박스 자막 스타일을 적용한다. `hasBackground == false` 면 패딩만 적용하고 면·테두리는 생략.
    func boxSubtitleStyle(fontPx: CGFloat, hasBackground: Bool) -> some View {
        modifier(BoxSubtitleStyle(fontPx: fontPx, hasBackground: hasBackground))
    }
}
