import SwiftUI
import UIKit

/// 키보드의 표시 높이와 상단 Y(전역 좌표)를 Observation 으로 노출한다.
/// 프로젝트 규약상 `ObservableObject`/`@Published`·GCD 금지 → `@Observable` + `NotificationCenter`
/// async 스트림(`for await`)으로 구독한다. `keyboardWillChangeFrame` 하나로 show/hide/frame 변화를 모두 처리.
@Observable
@MainActor
final class KeyboardObserver {
    /// 화면 하단 기준 키보드 표시 높이(pt). 내려가 있으면 0.
    private(set) var height: CGFloat = 0
    /// 키보드 상단의 전역(화면) Y 좌표. 내려가 있으면 매우 큰 값(가림 없음).
    private(set) var topY: CGFloat = .greatestFiniteMagnitude

    @ObservationIgnored private var task: Task<Void, Never>?

    func start() {
        guard task == nil else { return }
        task = Task { [weak self] in
            let stream = NotificationCenter.default.notifications(
                named: UIResponder.keyboardWillChangeFrameNotification
            )
            for await note in stream {
                guard let self else { return }
                self.apply(note)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    private func apply(_ note: Notification) {
        guard
            let end = (note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
            let screen = UIApplication.shared.connectedScenes
                .compactMap({ ($0 as? UIWindowScene)?.screen })
                .first
        else { return }
        let screenHeight = screen.bounds.height
        let visible = max(0, screenHeight - end.minY)   // 내려가면 end.minY ≈ screenHeight → 0
        height = visible
        topY = visible > 0 ? end.minY : .greatestFiniteMagnitude
    }
}
