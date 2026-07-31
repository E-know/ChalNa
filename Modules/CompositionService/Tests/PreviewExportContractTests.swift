import Foundation
import CoreGraphics
import Testing
import Models
import CompositionService

/// 프리뷰(`ClipFraming.resolvedRect`)와 export(`AVFoundationCompositionService.transform`)가
/// **같은 배치 사각형**을 만들어내는지 잠그는 계약 테스트.
///
/// 두 경로는 서로 독립적으로 구현돼 있다 — 프리뷰는 `CGRect`, export 는 AVFoundation 이 요구하는
/// `CGAffineTransform` — 이지만 둘 다 배율/오프셋 원시값은 `ClipFraming.fillScale`·`clampedOffset`
/// 을 그대로 호출해 공유한다. 그런데 이 둘을 실제로 비교하는 테스트는 지금까지 없었다.
/// Task 25 의 회귀(a6251a4 가 공유 캔버스의 `.frame(alignment:)` 를 top→center 로 바꿔
/// 라벨 드래그 좌표가 0.889pt 어긋난 사례, 84fdc1c 에서 테스트 없이 수정됨)가 정확히 이 지점에서
/// 났다 — "두 경로가 같은 값을 참조한다"는 사실이 "같은 결과를 낸다"를 자동으로 보장하지 않는다.
struct PreviewExportContractTests {
    let render = CGSize(width: 1080, height: 1920)

    /// naturalSize == display(=preferredTransform 은 identity 고정): `ClipFraming.resolvedRect` 의
    /// `display` 파라미터와 `transform()` 이 실제로 배치하는 대상을 동일하게 맞추기 위함
    /// (CompositionTransformTests 의 기존 관례와 동일).
    private func exportRect(display: CGSize, rotation: ClipRotation, transform: ClipTransform) -> CGRect {
        let t = AVFoundationCompositionService.transform(
            naturalSize: display,
            preferredTransform: .identity,
            rotation: rotation,
            renderSize: render,
            framing: transform
        )
        let corners = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: display.width, y: 0),
            CGPoint(x: 0, y: display.height),
            CGPoint(x: display.width, y: display.height)
        ].map { $0.applying(t) }
        let xs = corners.map(\.x), ys = corners.map(\.y)
        return CGRect(x: xs.min()!, y: ys.min()!, width: xs.max()! - xs.min()!, height: ys.max()! - ys.min()!)
    }

    /// 두 경로 모두 같은 `fillScale`/`clampedOffset` 값을 쓰지만, 이를 최종 좌표로 환산하는
    /// 곱셈 결합 순서가 다르다 — `resolvedRect` 는 `(size × fill) × scale`, `transform()` 은
    /// `size × (fill × scale)`(totalScale 을 먼저 합쳐서). 부동소수점 곱은 결합법칙이 없어
    /// 이 재결합만으로도 ULP 수준 잔차가 생길 수 있다. render 좌표 규모(~천 단위)에서 double
    /// ULP 는 ~1e-12 이고, 매트릭스 합성을 몇 단계 거치며 누적돼도 1e-6 이면 충분히 여유롭다 —
    /// 그러면서도 실제로 있었던 회귀(0.889pt)보다는 5~6 자릿수 더 엄격해, 그 급의 재발은 반드시 잡는다.
    private let tolerance: CGFloat = 1e-6

    private func expectContract(display: CGSize, rotation: ClipRotation, transform: ClipTransform) {
        let preview = ClipFraming.resolvedRect(display: display, rotation: rotation, render: render, transform: transform)
        let export = exportRect(display: display, rotation: rotation, transform: transform)
        #expect(abs(preview.minX - export.minX) < tolerance, "minX: preview \(preview.minX) vs export \(export.minX)")
        #expect(abs(preview.minY - export.minY) < tolerance, "minY: preview \(preview.minY) vs export \(export.minY)")
        #expect(abs(preview.width - export.width) < tolerance, "width: preview \(preview.width) vs export \(export.width)")
        #expect(abs(preview.height - export.height) < tolerance, "height: preview \(preview.height) vs export \(export.height)")
    }

    // MARK: - identity(스케일 1·오프셋 0)

    @Test func testContract_Landscape_R0_Identity() {
        expectContract(display: CGSize(width: 1920, height: 1080), rotation: .r0, transform: .fill)
    }

    @Test func testContract_Portrait_R0_Identity() {
        expectContract(display: CGSize(width: 1080, height: 1920), rotation: .r0, transform: .fill)
    }

    // MARK: - 회전(오리엔티드 축 swap)

    @Test func testContract_Landscape_R90_Identity() {
        expectContract(display: CGSize(width: 1920, height: 1080), rotation: .r90, transform: .fill)
    }

    @Test func testContract_Portrait_R90_Identity() {
        expectContract(display: CGSize(width: 1080, height: 1920), rotation: .r90, transform: .fill)
    }

    // MARK: - 비제로 scale + offset (clamp 미발동)

    @Test func testContract_Landscape_R0_ScaleAndOffset() {
        expectContract(display: CGSize(width: 1920, height: 1080), rotation: .r0,
                       transform: ClipTransform(scale: 2, offset: CGPoint(x: 0.2, y: 0)))
    }

    // MARK: - clampedOffset 이 실제로 clamp 되는 경로

    /// 가로 클립 scale=1: 이동 한계 ≈1.08025(ClipFramingTests 와 동일 값). offset.x=2.0 은 한계 초과.
    @Test func testContract_Landscape_R0_OffsetClamps() {
        expectContract(display: CGSize(width: 1920, height: 1080), rotation: .r0,
                       transform: ClipTransform(scale: 1, offset: CGPoint(x: 2.0, y: -0.5)))
    }

    /// 회전 + scale + clamp 조합 — 회전이 이동 한계 자체를 바꾸는 경로(ClipFramingTests 의
    /// `testMaxOffsetFraction_R90_Portrait_BecomesHorizontal` 참고)에서도 두 경로가 같은 clamp 를 본다.
    @Test func testContract_Portrait_R90_ScaleAndOffsetClamps() {
        expectContract(display: CGSize(width: 1080, height: 1920), rotation: .r90,
                       transform: ClipTransform(scale: 2, offset: CGPoint(x: 5.0, y: 5.0)))
    }
}
