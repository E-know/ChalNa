import Foundation
import CoreGraphics
import Testing
import Models

/// 자동 시각/날짜 라벨은 이제 **끌 수 없다**(우측 하단 고정). 그래서 라벨과 무관한 픽셀을
/// 검사하는 테스트들은 샘플 지점이 라벨 스탬프를 피하도록 좌표를 골라야 한다.
///
/// 예전에는 그 회피를 세 파일의 주석에 손으로 계산해 적어뒀다("대략 x≳857, y∈[1736,1843]").
/// 그러면 `LabelLayout.paddingFraction` 이나 폰트 분수를 바꾸는 순간 샘플 지점이 라벨에 걸리고,
/// 테스트는 **컴포지터를 가리키며** 실패한다("최하단도 YELLOW 전경이어야 함") — 진짜 원인은
/// 라벨 기하인데.
///
/// 이 가드는 같은 회피를 `LabelText.stampRect` 로 계산해서 확인한다. 기하가 바뀌면 여기서
/// 먼저, 올바른 원인을 지목하며 실패한다.
func expectClearOfAutoLabelStamp(
    _ points: [(x: Int, y: Int)],
    renderSize: CGSize = CGSize(width: 1080, height: 1920),
    capturedAt: Date,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    let stamp = LabelText.stampRect(renderSize: renderSize, capturedAt: capturedAt)
    for p in points {
        let point = CGPoint(x: CGFloat(p.x), y: CGFloat(p.y))
        #expect(
            !stamp.contains(point),
            """
            샘플 지점 (\(p.x), \(p.y)) 이 자동 라벨 스탬프 \(stamp) 안에 있다.
            컴포지터 버그가 아니라 라벨 기하(LabelLayout 의 padding/폰트 분수)가 바뀐 것이다 —
            샘플 지점을 옮기거나 기하 변경을 되돌려라.
            """,
            sourceLocation: sourceLocation
        )
    }
}
