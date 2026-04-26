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
        // letterbox 유지 — 외곽 띠 색은 PreviewPanel 의 ink 베이스가 그린다.
        view.playerLayer.videoGravity = .resizeAspect
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
