import Testing
import Foundation
import CoreGraphics
import SwiftUI
import Models

/// 프리뷰 자동 라벨(`AutoLabelsOverlay`)이 영상 출력과 **같은 비율**로 그려지는지.
///
/// 이 스위트의 존재 이유는 12pt 최소 폰트 규칙(CLAUDE.md Typography)의 예외를
/// **암묵이 아니라 명시**로 만드는 것이다. 프리뷰 박스가 작으면 라벨은 12pt 아래로 내려간다.
/// 그건 버그가 아니라 WYSIWYG 의 대가다 — 프리뷰에만 바닥값을 두면 출력 영상보다 라벨이
/// 크게 보여 미리보기가 거짓말을 한다. 가독성이 필요하면 폰트가 아니라 캔버스를 키워야 한다.
///
/// 누군가 바닥값을 넣으면 여기서 실패한다. 그때 필요한 건 조용한 수정이 아니라 이 결정의 재검토다.
struct AutoLabelsOverlayFidelityTests {

    /// iPhone 인라인 프리뷰의 9:16 박스 정도(폭 ~250pt).
    private let previewBox = CGSize(width: 250, height: 444)
    private let outputCanvas = CGSize(width: 1080, height: 1920)

    /// 프리뷰에서 라벨은 12pt 아래로 내려간다 — 의도된 예외.
    @Test func previewLabelsFallBelowTwelvePointsByDesign() {
        let minDim = min(previewBox.width, previewBox.height)
        let timePx = minDim * LabelLayout.timeFontFraction
        let datePx = minDim * LabelLayout.dateFontFraction

        #expect(timePx < 12, "시각 라벨이 12pt 이상이면 바닥값이 생긴 것 — WYSIWYG 재검토 필요: \(timePx)")
        #expect(datePx < 12, "날짜 라벨이 12pt 이상이면 바닥값이 생긴 것 — WYSIWYG 재검토 필요: \(datePx)")
    }

    /// 폰트 토큰이 요청 pt 를 그대로 쓴다(클램프 없음). 바닥값이 들어오면 여기서 잡힌다.
    @Test func fontTokenAppliesExactPointSizeWithoutClamping() {
        let tiny = min(previewBox.width, previewBox.height) * LabelLayout.dateFontFraction
        #expect(tiny < 12)
        #expect(LabelText.font(px: tiny) == Font.system(size: tiny, weight: LabelText.weight, design: .default))
    }

    /// 진짜 계약: 스탬프가 캔버스에서 차지하는 **상대 위치·크기**가 프리뷰와 출력에서 같아야 한다.
    /// (실측 `ceil` 과 그림자 여유 때문에 픽셀 단위로는 안 맞으므로 비율 허용오차를 둔다.)
    @Test func stampOccupiesSameRelativeBoxInPreviewAndOutput() {
        let date = Date(timeIntervalSince1970: 1_787_000_000)
        let locale = Locale(identifier: "ko")

        let preview = LabelText.stampRect(renderSize: previewBox, capturedAt: date, locale: locale)
        let output = LabelText.stampRect(renderSize: outputCanvas, capturedAt: date, locale: locale)

        func relative(_ r: CGRect, in size: CGSize) -> (x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat) {
            (r.minX / size.width, r.minY / size.height, r.width / size.width, r.height / size.height)
        }
        let p = relative(preview, in: previewBox)
        let o = relative(output, in: outputCanvas)

        // 허용오차는 눈대중이 아니라 계통 편차에서 유도한다. `shadowSlack` 은 **절대 pt** 라
        // 작은 프리뷰 박스에서 상대 비중이 훨씬 크다 — 이 차이는 WYSIWYG 위반이 아니라
        // 그림자 여유의 성질이다. 거기에 실측 ceil 여유 2%p 를 더한다.
        func slackSkew(_ previewDim: CGFloat, _ outputDim: CGFloat) -> CGFloat {
            2 * LabelText.shadowSlack * abs(1 / previewDim - 1 / outputDim)
        }
        let tolX = 0.02 + slackSkew(previewBox.width, outputCanvas.width)
        let tolY = 0.02 + slackSkew(previewBox.height, outputCanvas.height)

        #expect(abs(p.x - o.x) < tolX, "좌측 시작 비율 불일치: preview=\(p.x) output=\(o.x)")
        #expect(abs(p.y - o.y) < tolY, "상단 시작 비율 불일치: preview=\(p.y) output=\(o.y)")
        #expect(abs(p.w - o.w) < tolX, "폭 비율 불일치: preview=\(p.w) output=\(o.w)")
        #expect(abs(p.h - o.h) < tolY, "높이 비율 불일치: preview=\(p.h) output=\(o.h)")

        // 둘 다 우측 하단 코너에 있어야 한다.
        #expect(p.x > 0.5 && o.x > 0.5)
        #expect(p.y > 0.5 && o.y > 0.5)
    }
}
