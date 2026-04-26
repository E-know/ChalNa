import SwiftUI
import Models

/// 외곽 박스를 유지한 채 내부 콘텐츠만 90°/180°/270° 회전시키는 래퍼.
/// 90°·270°일 땐 GeometryReader로 inner frame의 width/height를 swap해서
/// 회전 후에도 콘텐츠가 외곽 박스 안에 정확히 채워지도록 한다.
struct RotatableContent<Content: View>: View {
    let rotation: ClipRotation
    @ViewBuilder let content: () -> Content

    var body: some View {
        if rotation.swapsAxes {
            GeometryReader { proxy in
                let outer = proxy.size
                content()
                    .frame(width: outer.height, height: outer.width)
                    .rotationEffect(.degrees(rotation.degrees))
                    .frame(width: outer.width, height: outer.height)
            }
        } else if rotation == .r180 {
            content()
                .rotationEffect(.degrees(180))
        } else {
            content()
        }
    }
}
