import SwiftUI
import Models
import DesignSystem

/// 자동 시간/날짜 라벨을 영상 출력과 동일하게 미리 보여주는 읽기 전용 오버레이.
/// 둘 다 항상 표시되고 불투명도는 `LabelLayout.opacity` 고정 — 사용자 설정은 없다.
/// `box` = 클립 표시 박스(에디터/미리보기의 fittedBox)를 renderSize 로 간주.
/// 위치는 우측 하단 고정이고, 레이아웃은 합성과 동일한 `LabelLayout` 을,
/// 문자열·폰트·실측은 `LabelText` 를 공유한다 (좌표는 y-up 좌하단 → SwiftUI y-down 변환).
///
/// **12pt 최소 크기 규칙(CLAUDE.md Typography)의 명시적 예외다.** 프리뷰 박스가 ~250pt 이면
/// 시각 ≈11pt, 날짜 ≈7.5pt 로 그려진다. 이건 UI 크롬 텍스트가 아니라 **영상 픽셀의 축소 재현**이라
/// (사진 안에 찍힌 작은 글씨와 같은 성격) 12pt 로 올리면 안 된다 — 올리는 순간 출력 영상보다
/// 라벨이 크게 보여 WYSIWYG 가 거짓이 된다. 가독성이 필요하면 폰트가 아니라 캔버스를 키워야 한다.
/// `AutoLabelsOverlayFidelityTests` 가 "바닥값 없이 분수에만 비례" 를 고정한다.
struct AutoLabelsOverlay: View {
    let box: CGSize
    let capturedAt: Date

    var body: some View {
        let minDim = min(box.width, box.height)
        let timeFont = minDim * LabelLayout.timeFontFraction
        let dateFont = minDim * LabelLayout.dateFontFraction
        let padding = CGSize(width: box.width * LabelLayout.paddingFraction,
                             height: box.height * LabelLayout.paddingFraction)
        let gap = minDim * LabelLayout.stackGapFraction
        // 로케일·포맷·폰트·실측은 전부 `LabelText`(Models) — 영상 합성이 쓰는 것과 같은 코드다.
        let locale = LabelText.locale()
        let timeText = LabelText.timeString(capturedAt, locale: locale)
        let dateText = LabelText.dateString(capturedAt, locale: locale)
        let timeSize = measure(timeText, fontPx: timeFont)
        let dateSize = measure(dateText, fontPx: dateFont)

        let origins = LabelLayout.stackedOrigins(
            timeSize: timeSize, dateSize: dateSize,
            gap: gap, renderSize: box, padding: padding
        )

        ZStack {
            label(dateText, fontPx: dateFont, originYUp: origins.date, size: dateSize)
            label(timeText, fontPx: timeFont, originYUp: origins.time, size: timeSize)
        }
        .frame(width: box.width, height: box.height)
        .allowsHitTesting(false)
    }

    private func measure(_ text: String, fontPx: CGFloat) -> CGSize {
        LabelText.measure(text, px: fontPx)
    }

    /// y-up 좌하단 origin → SwiftUI(y-down) 중심으로 변환해 배치.
    ///
    /// **색을 바꾸면 안 된다** — 이 라벨은 영상 출력과 픽셀 일치해야 한다.
    /// 출력이 흰 글자 + 검은 그림자이므로 미디어 위 마크용 테마 독립 토큰
    /// (`onMedia`·`onMediaDark`)을 쓴다 — 아래 픽셀이 어떤 사진/영상이든 대비를 보장해야 하기 때문이다.
    @ViewBuilder
    private func label(_ text: String, fontPx: CGFloat, originYUp: CGPoint, size: CGSize) -> some View {
        let topLeftY = box.height - originYUp.y - size.height
        let centerX = originYUp.x + size.width / 2
        let centerY = topLeftY + size.height / 2
        Text(text)
            .font(LabelText.font(px: fontPx))
            .foregroundColor(ChalNaColor.onMedia)
            .lineLimit(1)
            .fixedSize()
            .frame(width: size.width, height: size.height)
            .shadow(color: ChalNaColor.onMediaDark.opacity(0.5), radius: 4, x: 0, y: 2)
            .opacity(LabelLayout.opacity)
            .position(x: centerX, y: centerY)
    }
}
