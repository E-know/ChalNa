import CoreGraphics

/// 자동 시간/날짜 라벨 레이아웃의 단일 진실 공급원.
/// 영상 합성(CompositionService)과 에디터 미리보기(TimelineFeature)가 동일 계산을 공유해
/// WYSIWYG 가 어긋나지 않게 한다. 좌표는 CoreAnimation y-up(좌하단 원점) 기준.
public enum LabelLayout {
    /// 시각 라벨 글자 크기 = min(width,height) × 이 값.
    public static let timeFontFraction: CGFloat = 0.18
    /// 날짜 라벨 글자 크기 = min(width,height) × 이 값.
    public static let dateFontFraction: CGFloat = 0.035
    /// 캔버스 가장자리 안전 여백 = renderSize × 이 값.
    public static let paddingFraction: CGFloat = 0.04
    /// 시각/날짜 세로 스택 간격 = min(width,height) × 이 값.
    public static let stackGapFraction: CGFloat = 0.02

    /// 시각·날짜가 같은 구역일 때 세로 스택 배치 좌표(CoreAnimation y-up 좌하단).
    /// 시각이 위, 날짜가 아래. 그룹 전체 박스를 `position` 앵커로 정렬하고 각 라벨을 가로 가운데 정렬.
    public static func stackedOrigins(
        position: LabelPosition,
        timeSize: CGSize,
        dateSize: CGSize,
        gap: CGFloat,
        renderSize: CGSize,
        padding: CGSize
    ) -> (time: CGPoint, date: CGPoint) {
        let groupW = max(timeSize.width, dateSize.width)
        let groupH = timeSize.height + gap + dateSize.height
        let groupOrigin = position.origin(renderSize: renderSize, textSize: CGSize(width: groupW, height: groupH), padding: padding)
        let dateOrigin = CGPoint(x: groupOrigin.x + (groupW - dateSize.width) / 2, y: groupOrigin.y)
        let timeOrigin = CGPoint(x: groupOrigin.x + (groupW - timeSize.width) / 2, y: groupOrigin.y + dateSize.height + gap)
        return (timeOrigin, dateOrigin)
    }
}
