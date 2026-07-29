import SwiftUI

/// 9:16 미디어 캔버스 기하.
///
/// Timeline 프리뷰 · ClipAdjust · LabelEditor 세 곳이 거의 똑같이 재구현하던
/// aspect-fit 계산을 한 곳으로 모은다. WYSIWYG(프리뷰 = 출력) 의 토대다.
public enum ChalNaCanvasGeometry {
    /// 주어진 비율을 가용 영역 안에 aspect-fit 시킨 박스 크기.
    public static func fittedBox(aspect: CGFloat, in available: CGSize) -> CGSize {
        guard available.width > 0, available.height > 0, aspect > 0 else { return .zero }
        let byWidth = CGSize(width: available.width, height: available.width / aspect)
        if byWidth.height <= available.height { return byWidth }
        return CGSize(width: available.height * aspect, height: available.height)
    }
}

/// 영상·사진을 출력 비율(기본 9:16)로 담는 캔버스 컨테이너.
///
/// 배경은 `ChalNaColor.canvas`(진짜 검정). `bg` 와 거의 같은 밝기라
/// 화면 위에 '검은 섬'으로 뜨지 않는다.
///
/// `content` 와 `overlay` 는 확정된 박스 크기를 인자로 받는다 —
/// 라벨 좌표 정규화가 이 크기를 renderSize 로 삼기 때문이다.
public struct ChalNaCanvas<Content: View, Overlay: View>: View {
    private let aspect: CGFloat
    private let cornerRadius: CGFloat
    private let content: (CGSize) -> Content
    private let overlay: (CGSize) -> Overlay

    public init(
        aspect: CGFloat = 9.0 / 16.0,
        cornerRadius: CGFloat = ChalNaRadius.md,
        @ViewBuilder content: @escaping (CGSize) -> Content,
        @ViewBuilder overlay: @escaping (CGSize) -> Overlay
    ) {
        self.aspect = aspect
        self.cornerRadius = cornerRadius
        self.content = content
        self.overlay = overlay
    }

    public init(
        aspect: CGFloat = 9.0 / 16.0,
        cornerRadius: CGFloat = ChalNaRadius.md,
        @ViewBuilder content: @escaping (CGSize) -> Content
    ) where Overlay == EmptyView {
        self.init(aspect: aspect, cornerRadius: cornerRadius, content: content) { _ in EmptyView() }
    }

    public var body: some View {
        GeometryReader { proxy in
            let box = ChalNaCanvasGeometry.fittedBox(aspect: aspect, in: proxy.size)
            ZStack {
                ChalNaColor.canvas
                content(box)
            }
            .frame(width: box.width, height: box.height)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay { overlay(box) }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        ChalNaCanvas { box in
            LinearGradient(colors: [.indigo, .black], startPoint: .top, endPoint: .bottom)
                .frame(width: box.width, height: box.height)
        } overlay: { _ in
            ChalNaTag("3 / 8", variant: .neutral)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(12)
        }
        .frame(height: 320)
    }
    .padding(20)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ChalNaColor.bg)
}
