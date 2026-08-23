import Testing
import CoreGraphics
import Models

/// 자동 라벨 기하 — 우측 하단 고정. 프리뷰(AutoLabelsOverlay)와 합성이 공유하는 계산이므로
/// 여기가 깨지면 WYSIWYG 도 같이 깨진다.
struct LabelLayoutTests {
    let render = CGSize(width: 1000, height: 2000)
    let pad = CGSize(width: 40, height: 80)

    @Test func origin_isBottomRight_insidePadding() {
        let o = LabelLayout.origin(renderSize: render, textSize: CGSize(width: 100, height: 40), padding: pad)
        #expect(o.x == 860)   // 1000 - 40 - 100
        #expect(o.y == 80)    // CoreAnimation y-up: 하단 = 작은 y
    }

    @Test func origin_clampsTextWiderThanCanvas() {
        let o = LabelLayout.origin(renderSize: render, textSize: CGSize(width: 5000, height: 40), padding: pad)
        #expect(o.x == 40)    // 좌측 여백으로 클램프 — 캔버스 밖으로 안 나간다
    }

    @Test func stackedOrigins_timeAboveDate_bothRightAligned() {
        let timeSize = CGSize(width: 300, height: 60)
        let dateSize = CGSize(width: 120, height: 40)
        let gap: CGFloat = 12

        let r = LabelLayout.stackedOrigins(
            timeSize: timeSize, dateSize: dateSize,
            gap: gap, renderSize: render, padding: pad
        )
        // date(아래): x = 1000-40-120 = 840, y = 80
        // time(위):   x = 1000-40-300 = 660, y = 80+40+12 = 132
        #expect(r.date == CGPoint(x: 840, y: 80))
        #expect(r.time == CGPoint(x: 660, y: 132))
        #expect(r.time.y > r.date.y)                                  // 시각이 위 (y-up)
        #expect(r.time.x + timeSize.width == r.date.x + dateSize.width) // 오른쪽 끝 일치
    }

    /// 우측 하단 코너 스탬프에 맞게 줄인 값. 시각이 날짜보다 크되 둘 다 캔버스를 가리지 않아야 한다.
    @Test func fontFractionsAreCornerStampSized() {
        #expect(LabelLayout.timeFontFraction == 0.045)   // 1080 기준 ≈49px
        #expect(LabelLayout.dateFontFraction == 0.030)   // 1080 기준 ≈32px
        #expect(LabelLayout.timeFontFraction > LabelLayout.dateFontFraction)
    }
}
