import CoreGraphics

/// UIScrollView 스타일 러버밴드(고무줄 저항) 공식.
/// 크롭 조정 드래그가 한계를 넘으면 초과분을 감쇠시켜 "한계에 닿았다"는 느낌을 준다.
///
/// 공식(iOS UIScrollView, c = 0.55): `b = (1 − 1/((x·c/d) + 1))·d`
/// x = 한계 초과 거리, d = 기준 치수, b = 실제 표시 밀림량. x→∞ 일 때 b→d 로 캡핑된다.
/// 정규화 offset 공간(비율)에서는 dimension = 1 로 쓰면 포인트 공간 공식과 동치.
public enum RubberBand {
    /// UIScrollView 가 쓰는 표준 저항 계수.
    public static let coefficient: CGFloat = 0.55

    /// 한계 초과분(excess ≥ 0)을 감쇠된 표시 초과분으로 변환. 음수 입력은 0 취급.
    public static func displacement(
        excess: CGFloat, dimension: CGFloat = 1.0, coefficient: CGFloat = coefficient
    ) -> CGFloat {
        guard excess > 0, dimension > 0 else { return 0 }
        return (1.0 - 1.0 / ((excess * coefficient / dimension) + 1.0)) * dimension
    }

    /// 1차원 값에 러버밴드 적용: [min, max] 안이면 그대로, 밖이면 초과분만 감쇠해 되돌려준다.
    public static func value(
        proposed: CGFloat, min lower: CGFloat, max upper: CGFloat,
        dimension: CGFloat = 1.0, coefficient: CGFloat = coefficient
    ) -> CGFloat {
        if proposed > upper {
            return upper + displacement(excess: proposed - upper, dimension: dimension, coefficient: coefficient)
        }
        if proposed < lower {
            return lower - displacement(excess: lower - proposed, dimension: dimension, coefficient: coefficient)
        }
        return proposed
    }
}
