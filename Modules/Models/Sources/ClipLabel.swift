import CoreGraphics
import Foundation
import SwiftUI

/// 편집 세션 동안 클립별로 사용자가 붙이는 박스 자막. 회전(`ClipRotation`)과 같은 per-clip 메타로,
/// 불변 `Clip` 이 아니라 `EditSession` 의 딕셔너리에 담는다.
///
/// 스타일은 `hasBackground` 로 갈린다:
/// - `true`  — 흰 배경 + 검정 글씨 + 검정 테두리 박스
/// - `false` — 배경·테두리 없는 흰 글씨(장식 없음)
///
/// 사용자가 정하는 것은 문구 · 크기 · 위치 · 배경 유무 · 기울기 다섯 가지다.
public struct ClipLabel: Hashable, Sendable {
    /// 자막 문구. 빈/공백 문자열이면 자막 없음으로 취급.
    public var text: String
    /// 9:16 캔버스 높이 대비 글자 크기 비율. `clampedSizeFraction` 으로 0.04...0.25 클램프해 사용.
    public var sizeFraction: CGFloat
    /// 9:16 캔버스 기준 정규화 위치(자막 중심). x,y ∈ 0...1, y는 위(0)→아래(1) 스크린 방향.
    public var position: CGPoint
    /// 배경 박스(흰 면 + 검정 테두리) 표시 여부. false 면 흰 글자만 그린다.
    ///
    /// **패딩은 ON/OFF 에서 동일하다.** 근거가 두 개다.
    /// ① 합성(`customLabelOrigin`)은 텍스트 크기만으로 중심을 정하므로 패딩과 무관하다.
    /// ② 자동 축소(`ClipLabelMetrics.fittedSizeFraction`)의 판정 대상이 **패딩 포함 박스 폭**이라,
    ///    패딩이 갈리면 ON/OFF 에서 축소 결과 폰트가 갈린다.
    ///
    /// 에디터(`LabelEditorView`)는 정규화 **중심**을 배치의 단일 출처로 쓰므로 패딩이 달라져도
    /// 라벨이 움직이지 않는다 — 좌상단 코너를 고정하던 시절의 근거("패딩이 바뀌면 코너는
    /// 그대로여도 중심이 옮겨간다")는 더 이상 유효하지 않다.
    public var hasBackground: Bool

    /// 라벨 기울기(radian). **시계방향이 +**, 0 이 수평. −π…π 자유 회전이며
    /// `clampedRotationRadians` 로 clamp 해 사용한다.
    ///
    /// 프리뷰와 합성의 부호 규약은 `previewRotation`/`layerRotationTransform` 두 파생값에만
    /// 둔다 — 합성 오버레이 부모 레이어가 `isGeometryFlipped = true` 라 부호를 호출처마다
    /// 손으로 맞추면 두 경로가 조용히 어긋난다. 실제 시각 방향은
    /// `CompositionServiceTests/ClipLabelRotationTests` 가 오버레이 비트맵 픽셀로 잠근다.
    ///
    /// **자동 축소는 회전 전(unrotated) 박스 폭 기준이다** —
    /// `ClipLabelMetrics.fittedSizeFraction` 이 회전을 인자로 받지 않으므로 구조적으로 그렇다.
    /// 회전된 바운딩 박스가 캔버스를 넘는 것은 허용한다: 사용자가 의도적으로 기울인 결과이고,
    /// 회전할 때마다 폰트가 흔들리는 것이 더 나쁘다.
    public var rotationRadians: CGFloat

    public init(
        text: String = "",
        sizeFraction: CGFloat = 0.10,
        position: CGPoint = CGPoint(x: 0.5, y: 0.5),
        hasBackground: Bool = true,
        rotationRadians: CGFloat = 0
    ) {
        self.text = text
        self.sizeFraction = sizeFraction
        self.position = position
        self.hasBackground = hasBackground
        self.rotationRadians = rotationRadians
    }

    /// 화면/영상에 그릴 자막이 있는지.
    public var isVisible: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 슬라이더 허용 범위.
    public static let minSizeFraction: CGFloat = 0.04
    public static let maxSizeFraction: CGFloat = 0.25

    /// 클램프된 크기 비율.
    public var clampedSizeFraction: CGFloat {
        min(max(sizeFraction, Self.minSizeFraction), Self.maxSizeFraction)
    }

    /// 자유 회전 한계 — 반 바퀴(±180°).
    public static let rotationLimit: CGFloat = .pi
    /// 에디터에서 0° 로 스냅되는 임계(±3°). 위치 드래그의 중심 스냅과 같은 패턴이다.
    public static let rotationSnapRadians: CGFloat = 3 * .pi / 180

    /// 클램프된 기울기.
    public var clampedRotationRadians: CGFloat {
        min(max(rotationRadians, -Self.rotationLimit), Self.rotationLimit)
    }

    /// 프리뷰(SwiftUI `.rotationEffect`)용 각도. 시계방향 +.
    public var previewRotation: Angle { .radians(Double(clampedRotationRadians)) }

    /// 합성(CALayer)용 아핀. 부모 레이어가 `isGeometryFlipped = true` 인 상태에서
    /// 프리뷰와 **같은 방향**으로 보이는 부호를 여기 한곳에만 둔다.
    public var layerRotationTransform: CGAffineTransform {
        CGAffineTransform(rotationAngle: clampedRotationRadians)
    }

    public static let `default` = ClipLabel()
}

public extension ClipLabel {
    /// 박스 자막 스타일 상수. 프리뷰(SwiftUI)와 영상 합성(CALayer)이 같은 값을 참조해 WYSIWYG 를 맞춘다.
    /// 모든 값은 폰트 픽셀(fontSize) 기준 비율.
    enum BoxStyle {
        /// 테두리 두께 = fontSize × 이 값.
        public static let borderWidthFraction: CGFloat = 0.06
        /// 가로 안쪽 여백 = fontSize × 이 값.
        public static let horizontalPaddingFraction: CGFloat = 0.35
        /// 세로 안쪽 여백 = fontSize × 이 값.
        public static let verticalPaddingFraction: CGFloat = 0.22
        /// 자간(letter spacing) = fontSize × 이 값. 음수면 자간이 좁아진다. (더 좁히려면 -0.06, -0.08 …)
        public static let letterSpacingFraction: CGFloat = -0.06

        /// fontSize 에 대한 실제 자간(point). 프리뷰(.tracking)·합성(NSAttributedString.kern)이 공유.
        public static func letterSpacing(for fontSize: CGFloat) -> CGFloat {
            fontSize * letterSpacingFraction
        }
    }
}
