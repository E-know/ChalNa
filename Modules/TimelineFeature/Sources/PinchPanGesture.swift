import SwiftUI
import UIKit

/// 핀치 줌 + (1~2 손가락) 팬을 동시에 인식하는 UIKit 제스처 호스트.
/// SwiftUI 제스처로는 두 손가락 팬 추적이 불안정해 UIKit 인식기로 대체.
/// onChange: 이번 프레임 변화분 — scaleFactor(배수, 1=변화없음), translation(points 델타).
/// onEnded: 활성 제스처(핀치 또는 팬) 종료 시 — 커밋 트리거.
struct PinchPanGesture: UIViewRepresentable {
    var onChange: (_ scaleFactor: CGFloat, _ translation: CGSize) -> Void
    var onEnded: () -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true
        let pinch = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        pan.minimumNumberOfTouches = 1
        pan.maximumNumberOfTouches = 2
        pinch.delegate = context.coordinator
        pan.delegate = context.coordinator
        view.addGestureRecognizer(pinch)
        view.addGestureRecognizer(pan)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onChange = onChange
        context.coordinator.onEnded = onEnded
    }

    func makeCoordinator() -> Coordinator { Coordinator(onChange: onChange, onEnded: onEnded) }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onChange: (CGFloat, CGSize) -> Void
        var onEnded: () -> Void
        init(onChange: @escaping (CGFloat, CGSize) -> Void, onEnded: @escaping () -> Void) {
            self.onChange = onChange
            self.onEnded = onEnded
        }
        @objc func handlePinch(_ g: UIPinchGestureRecognizer) {
            switch g.state {
            case .changed:
                onChange(g.scale, .zero)
                g.scale = 1
            case .ended, .cancelled, .failed:
                onEnded()
            default:
                break
            }
        }
        @objc func handlePan(_ g: UIPanGestureRecognizer) {
            switch g.state {
            case .changed:
                let t = g.translation(in: g.view)
                onChange(1, CGSize(width: t.x, height: t.y))
                g.setTranslation(.zero, in: g.view)
            case .ended, .cancelled, .failed:
                onEnded()
            default:
                break
            }
        }
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            true
        }
    }
}
