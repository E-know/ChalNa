import SwiftUI
import AVFoundation

/// SwiftUI에서 `AVPlayer`를 렌더하기 위한 최소한의 UIKit 래퍼.
/// 커스텀 UI(프리뷰 패널의 자체 플레이 버튼·스크럽바)를 그대로 쓰기 위해
/// SwiftUI의 `VideoPlayer` 대신 AVPlayerLayer를 직접 붙인다.
struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerHostView {
        let view = PlayerHostView()
        view.playerLayer.player = player
        // 센터 크롭 프레이밍: 프레임(resolvedRect)이 이미 영상 비율과 일치하므로 보통 fit=fill.
        // displaySize 메타 로드 실패(9:16 폴백)처럼 프레임 비율이 어긋난 경우에도
        // export(aspectFill 센터 크롭)와 같은 모습이 되도록 fill 로 둔다.
        view.playerLayer.videoGravity = .resizeAspectFill
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: PlayerHostView, context: Context) {
        if uiView.playerLayer.player !== player {
            uiView.playerLayer.player = player
        }
    }
}

final class PlayerHostView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}
