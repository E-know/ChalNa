import SwiftUI
import Testing
@testable import TimelineFeature

/// 박스 자막 색 팔레트가 합성(`CATextLayer`)과 같은 규칙을 쓰는지 값 수준에서 잠근다.
/// 합성 쪽 대응 가드는 `CompositionServiceTests/CustomLabelLayoutTests` 다 —
/// 두 렌더 경로가 색을 따로 결정하면 WYSIWYG 가 조용히 어긋난다.
struct ClipLabelBoxPaletteTests {

    /// 배경 ON: 흰 박스 위 검정 글씨.
    @Test func foregroundWithBackgroundIsBlack() {
        #expect(ClipLabelBoxPalette.foreground(hasBackground: true, placeholder: false) == Color.black)
    }

    /// 배경 OFF: 영상 위 직접이라 흰 글씨.
    @Test func foregroundWithoutBackgroundIsWhite() {
        #expect(ClipLabelBoxPalette.foreground(hasBackground: false, placeholder: false) == Color.white)
    }

    /// placeholder 는 같은 색의 50% — 배경 유무와 무관하게 같은 규칙.
    @Test func placeholderDimsSameBase() {
        #expect(ClipLabelBoxPalette.foreground(hasBackground: true, placeholder: true)
                == Color.black.opacity(0.5))
        #expect(ClipLabelBoxPalette.foreground(hasBackground: false, placeholder: true)
                == Color.white.opacity(0.5))
    }

    /// 박스 면·테두리 색은 합성(bgLayer)과 동일해야 한다.
    @Test func boxColorsMatchComposition() {
        #expect(ClipLabelBoxPalette.boxFill == Color.white)
        #expect(ClipLabelBoxPalette.boxBorder == Color.black)
    }
}
