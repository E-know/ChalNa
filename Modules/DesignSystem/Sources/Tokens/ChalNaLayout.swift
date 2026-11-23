import CoreGraphics

public enum ChalNaLayout {
    /// 가용 영역에 영상과 편집 패널을 나란히 놓을 수 있는지 판정한다.
    public static func isSplit(_ size: CGSize) -> Bool {
        size.width >= 700 && size.width > size.height
    }
}
