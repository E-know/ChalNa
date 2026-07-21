import Foundation
import Testing
import CoreGraphics
import Models
@testable import CompositionService

struct CustomLabelLayoutTests {

    // 정중앙(0.5,0.5) 라벨의 좌하단 origin (CoreAnimation y-up).
    // 센터 크롭에서 자막 앵커 기준(placedRect) = 캔버스 전체.
    @Test func customLabelOriginCenter() {
        let placed = CGRect(x: 0, y: 0, width: 1080, height: 1920)
        let origin = AVFoundationCompositionService.customLabelOrigin(
            placedRect: placed,
            position: CGPoint(x: 0.5, y: 0.5),
            textSize: CGSize(width: 200, height: 80),
            renderSize: CGSize(width: 1080, height: 1920)
        )
        // 중심 top-down=(540,960) → y-up center=960 → origin=(440,920)
        #expect(origin.x == 440)
        #expect(origin.y == 920)
    }

    // 상단(0.5,0.1) — 화면 위쪽이면 y-up origin 이 커진다.
    @Test func customLabelOriginTopArea() {
        let placed = CGRect(x: 0, y: 0, width: 1080, height: 1920)
        let origin = AVFoundationCompositionService.customLabelOrigin(
            placedRect: placed,
            position: CGPoint(x: 0.5, y: 0.1),
            textSize: CGSize(width: 300, height: 100),
            renderSize: CGSize(width: 1080, height: 1920)
        )
        // 중심 top-down=(540,192) → y-up center=1728 → origin=(390,1678)
        #expect(origin.x == 390)
        #expect(origin.y == 1678)
    }

    // 정규화 좌표는 0...1 로 클램프된다.
    @Test func customLabelOriginClamps() {
        let placed = CGRect(x: 0, y: 0, width: 1000, height: 2000)
        let origin = AVFoundationCompositionService.customLabelOrigin(
            placedRect: placed,
            position: CGPoint(x: 2.0, y: -1.0),  // → (1, 0)
            textSize: CGSize(width: 100, height: 40),
            renderSize: CGSize(width: 1000, height: 2000)
        )
        // 중심 top-down=(1000,0) → y-up center=2000 → origin=(950,1980)
        #expect(origin.x == 950)
        #expect(origin.y == 1980)
    }
}
