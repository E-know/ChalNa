import CoreGraphics

/// 자동 시간/날짜 라벨 레이아웃의 단일 진실 공급원.
/// 영상 합성(CompositionService)과 에디터 미리보기(TimelineFeature)가 동일 계산을 공유해
/// WYSIWYG 가 어긋나지 않게 한다. 좌표는 CoreAnimation y-up(좌하단 원점) 기준.
///
/// 위치는 **우측 하단 고정**이다 — 사용자가 고를 수 있는 9구역 체계(`LabelPosition`)는 없앴다.
/// 시각·날짜 둘 다 켜져 있으면 시각이 위, 날짜가 아래로 쌓이고 둘 다 우측 정렬된다.
public enum LabelLayout {
    /// 시각 라벨 글자 크기 = min(width,height) × 이 값. (1080 캔버스 기준 ≈49px)
    public static let timeFontFraction: CGFloat = 0.045
    /// 날짜 라벨 글자 크기 = min(width,height) × 이 값. (1080 캔버스 기준 ≈32px)
    public static let dateFontFraction: CGFloat = 0.030
    /// 캔버스 가장자리 안전 여백 = renderSize × 이 값.
    public static let paddingFraction: CGFloat = 0.04
    /// 시각/날짜 세로 스택 간격 = min(width,height) × 이 값. (1080 기준 ≈11px)
    public static let stackGapFraction: CGFloat = 0.010
    /// 시각·날짜 공통 불투명도. 사용자 설정이 아니라 고정값이다 — 설정 화면은 삭제됐다.
    public static let opacity: Double = 0.75

    /// 라벨 하나의 우측 하단 origin(좌하단 원점).
    /// 텍스트가 여백을 뺀 폭보다 넓으면 좌측 여백으로 클램프해 캔버스 밖으로 안 나간다.
    public static func origin(renderSize: CGSize, textSize: CGSize, padding: CGSize) -> CGPoint {
        CGPoint(
            x: max(padding.width, renderSize.width - padding.width - textSize.width),
            y: padding.height
        )
    }

    /// 시각·날짜를 우측 하단에 세로로 쌓은 좌표. 시각이 위(큰 y), 날짜가 아래.
    /// 각 라벨을 독립적으로 우측 정렬하므로 폭이 달라도 오른쪽 끝이 맞는다.
    public static func stackedOrigins(
        timeSize: CGSize,
        dateSize: CGSize,
        gap: CGFloat,
        renderSize: CGSize,
        padding: CGSize
    ) -> (time: CGPoint, date: CGPoint) {
        let date = origin(renderSize: renderSize, textSize: dateSize, padding: padding)
        let time = CGPoint(
            x: origin(renderSize: renderSize, textSize: timeSize, padding: padding).x,
            y: date.y + dateSize.height + gap
        )
        return (time, date)
    }
}
