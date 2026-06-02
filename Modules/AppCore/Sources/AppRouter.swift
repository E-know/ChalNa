import Foundation
import Models
import Observation

/// 루트 NavigationStack의 라우트 열거형. Home은 루트에서 렌더하므로 스택에 push하지 않음.
public enum Route: Hashable, Sendable {
    case mediaPicker
    case timeline
    case export
    case filmDetail(filmID: UUID)
    case settings
    case labelSettings
    case labelPosition(LabelKind)
    case support
    case clipAdjust(clipID: UUID)
}

/// AppFeature(TCA) 의 path 와 연결되는 thin wrapper.
/// Feature view 들에서 기존 `router.push/pop/popToRoot` 호출 호환을 위해 유지.
/// RootView 가 onAppear 시 handler 3 개를 store.send 로 와이어한다.
@Observable
public final class AppRouter {
    public var pushHandler: ((Route) -> Void)?
    public var popHandler: (() -> Void)?
    public var popToRootHandler: (() -> Void)?

    public init() {}

    public func push(_ route: Route) { pushHandler?(route) }
    public func pop() { popHandler?() }
    public func popToRoot() { popToRootHandler?() }
}
