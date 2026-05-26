import SwiftUI
import UIKit

public extension View {
    /// 시스템 NavigationBar 를 숨기거나 back 버튼을 가린 화면에서도
    /// 좌측 엣지 스와이프-백 제스처가 살아 있도록 보강한다.
    ///
    /// `NavigationStack` 은 내부적으로 `UINavigationController` 위에서 동작한다.
    /// `.toolbar(.hidden, for: .navigationBar)` 또는 `navigationBarBackButtonHidden(true)`
    /// 을 걸면 시스템이 `interactivePopGestureRecognizer.delegate` 를 분리해
    /// 제스처가 비활성화되는데, 이 모디파이어는 화면이 표시될 때마다 delegate 를 재바인딩한다.
    func chalNaSwipeBack() -> some View {
        background(SwipeBackInstaller())
    }
}

/// SwiftUI 뷰 트리에 끼워 넣어 `UINavigationController.interactivePopGestureRecognizer` 의
/// delegate 를 채로 다시 살려주는 invisible representable.
private struct SwipeBackInstaller: UIViewControllerRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = ProbeViewController()
        viewController.coordinator = context.coordinator
        return viewController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    /// 루트(스택에 1개)에서는 뒤로 갈 곳이 없으므로 제스처를 비활성. 그 외에는 항상 활성.
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        weak var navigationController: UINavigationController?

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            (navigationController?.viewControllers.count ?? 0) > 1
        }
    }

    private final class ProbeViewController: UIViewController {
        var coordinator: Coordinator?

        override func viewDidLoad() {
            super.viewDidLoad()
            view.isUserInteractionEnabled = false
            view.backgroundColor = .clear
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            guard let nav = navigationController, let coordinator else { return }
            coordinator.navigationController = nav
            nav.interactivePopGestureRecognizer?.isEnabled = true
            nav.interactivePopGestureRecognizer?.delegate = coordinator
        }
    }
}
